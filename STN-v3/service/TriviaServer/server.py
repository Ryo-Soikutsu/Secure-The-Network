import os
import json
import string

COLOR_RED = "\033[91m{}\033[00m"
COLOR_GREEN = "\033[92m{}\033[00m"
COLOR_YELLOW = "\033[93m{}\033[00m"
COLOR_LIGHT_PURPLE = "\033[94m{}\033[00m"
COLOR_PURPLE = "\033[95m{}\033[00m"
COLOR_CYAN = "\033[96m{}\033[00m"
COLOR_LIGHT_GRAY = "\033[97m{}\033[00m"
COLOR_BLACK = "\033[98m{}\033[00m"

REPLACE_CHARS = string.ascii_letters + string.digits
CONNECTION_BANNER = """
\033[1;34m┌────────────────────────────────────────────────┐\033[0m
\033[1;34m│\033[1;33m        ____       _                            \033[1;34m│\033[0m
\033[1;34m│\033[1;33m       |  _ \\ ___ | | __ _ _ __(_)___           \033[1;34m│\033[0m
\033[1;34m│\033[1;33m       | |_) / _ \\| |/ _` | '__| / __|          \033[1;34m│\033[0m
\033[1;34m│\033[1;33m       |  __/ (_) | | (_| | |  | \\__ \\          \033[1;34m│\033[0m
\033[1;34m│\033[1;33m       |_|   \\___/|_|\\__,_|_|  |_|___/          \033[1;34m│\033[0m
\033[1;34m│\033[1;36m          Northland Forensics Server            \033[1;34m│\033[0m
\033[1;34m│\033[1;31m    “The truth is hidden in plain sight.”       \033[1;34m│\033[0m
\033[1;34m└────────────────────────────────────────────────┘\033[0m

\033[1;32mWelcome, investigator. Your assignment awaits.\033[0m
"""

QUESTIONS_BANNER = """
\033[1;35m╔═════════════════════════════════════════════╗\033[0m
\033[1;35m║\033[1;37m  Question \033[1;33m{}\033[1;37m of \033[1;33m{}  \033[1;35m\033[0m
\033[1;35m╠═════════════════════════════════════════════╣\033[0m\n
\033[1;37m  {}\033[0m

\033[1;90mHint:\033[0m \033[1;33m{}\033[0m
"""

with open("config.json", "r") as f:
    config = json.load(f)

print(CONNECTION_BANNER)
total_questions = len(config["questions"])
for i, question in enumerate(config["questions"]):
    hint = ""
    if question.get("hint") is not None:
        hint = question["hint"]
    else:
        for char in question["answer"]:
            if char in REPLACE_CHARS:
                hint += "*"
            else:
                hint += char
            
    print(QUESTIONS_BANNER.format(i+1, total_questions, question["question"], hint))
    guess = input("\033[1;32m> \033[0m")
    while guess != question["answer"]:
        print(COLOR_RED.format("Answer incorrect, please try again"))
        guess = input("\033[1;32m> \033[0m")
    
    print(COLOR_GREEN.format("Answer correct! Next question..."))

print("\n")
print(COLOR_LIGHT_GRAY.format("All questions answered correctly. Assignment complete."))
flag = os.getenv("FLAG")
if not flag:
    print(COLOR_RED.format("An error has occurred when trying to retrieve the flag. Please open a ticket in the Discord server for help."))
else:  
    print(COLOR_LIGHT_GRAY.format(f"Here is your flag: {COLOR_YELLOW.format(flag)}"))