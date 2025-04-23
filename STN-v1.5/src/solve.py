from scapy.all import rdpcap, DNS, DNSQR, DNSRR
import tqdm
import base64

def extract_dns_requests(pcap_file):
    # Load the PCAP file
    print("Loading pcap file")
    packets = rdpcap(pcap_file)
    print("pcap file loaded")
    dns_requests = []

    # Loop through all packets in the PCAP file
    for packet in tqdm.tqdm(packets):
        # Check if the packet has a DNS layer
        if packet.haslayer(DNS):
            dns_layer = packet[DNS]

            # Check if it's a query (qr = 0)
            if dns_layer.qr == 0 and (dns_layer.qd.qtype == 16 or dns_layer.qd.qtype == 0):  # QR = 0 for Query, QTYPE = 16 for TXT
                query_name = dns_layer.qd.qname.decode().strip(".")
                dns_requests.append({
                    "type": "query",
                    "name": query_name
                })

            # Check if it's a response (qr = 1)
            elif dns_layer.qr == 1:  # QR = 1 for Response
                for i in range(dns_layer.ancount):  # Loop through all answers
                    answer = dns_layer.an[i]
                    if answer.type == 16:  # Type 16 = TXT
                        response_name = answer.rrname.decode().strip(".")
                        response_data = b"".join(answer.rdata).decode()
                        dns_requests.append({
                            "type": "response",
                            "name": response_name,
                            "data": response_data
                        })
    return dns_requests




def encrypt_decrypt(data, key="5upErS3cr3tK3y", encrypt=True):
    key_length = len(key)
    if isinstance(data, str):
        data = data.encode()
    result = bytes(b ^ ord(key[i % key_length]) for i, b in enumerate(data))
    if encrypt:
        return base64.b64encode(result).decode('utf-8')
    else:
        decoded_data = base64.b64decode(data)
        decrypted_result = bytes(
            b ^ ord(key[i % key_length]) for i, b in enumerate(decoded_data))
        return decrypted_result.decode('utf-8', errors='ignore')


if __name__ == "__main__":
    # Path to the PCAP file
    pcap_path = "capture.pcap"

    # Extract DNS requests
    dns_data = extract_dns_requests(pcap_path)

    # Display extracted data
    for entry in dns_data:
        if entry["type"] == "query":
            if "result" in entry['name']:
                print(f"DNS Query: {encrypt_decrypt(entry['name'].split('.')[1],encrypt=False)}")
        if entry["type"] == "response":
            if entry['data']:
                print(f"DNS Response: {entry['name']} -> {encrypt_decrypt(entry['data'],encrypt=False)}")