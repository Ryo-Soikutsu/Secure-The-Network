import os
import json
import string

BANNER = "Logged into the Northland Forensics server. Answer all questions to complete the assignment.\n"
REPLACE_CHARS = string.ascii_letters + string.digits
print(REPLACE_CHARS)

with open("questions.json") as f:
    questions: list = json.load(f)["questions"]

print(BANNER)
for i, question in enumerate(questions):
    print(f"Question {i+1}: {question['question']}")
    answer_hint = ""
    for char in question["answer"]:
        if char in REPLACE_CHARS:
            answer_hint += "*"
        else:
            answer_hint += char
            
    print(f"Hint: {answer_hint}\n")
    answer = input("> ")
    if answer != question["answer"]:
        print("Incorrect answer. Exiting...")
        exit(1)

print("All questions answered correctly. Assignment marked as completed.")
flag = os.getenv("FLAG")
print(f"Admin message: {flag}")