import os
import json

BANNER = "Logged into the Northland Forensics server. Answer all questions to complete the assignment.\n"

with open("questions.json") as f:
    questions: list = json.load(f)["questions"]

print(BANNER)
for i, question in enumerate(questions):
    print(f"Question {i+1}: {question['question']}\n")
    answer = input("> ")
    if answer != question["answer"]:
        print("Incorrect answer. Exiting...")
        exit(1)

print("All questions answered correctly. Assignment marked as completed.")
print(f"Admin message: {os.getenv("FLAG")}")