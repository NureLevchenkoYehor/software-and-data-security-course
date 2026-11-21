import csv

alphabet = 'абвгґдеєжзиіїйклмнопрстуфхцчшщьюя'

def decrypt(encrypted_message, key):
    decrypted = ''
    for char in encrypted_message:
        if char.lower() not in alphabet:
            decrypted += char
            continue
        index = alphabet.find(char.lower())
        target = (index - key) % len(alphabet)
        decrypted_char = alphabet[target]
        decrypted += decrypted_char.upper() if char.isupper() else decrypted_char
    return decrypted

with open('1.csv', newline='') as csvfile:
    spamreader = csv.reader(csvfile, delimiter='|')
    next(spamreader, None)
    for row in spamreader:
        encrypted = row[0].strip()
        key = int(row[1])
        original = row[2].strip()
        decrypted = decrypt(encrypted, key)
        print(f'\nEncrypted: [{encrypted}]\nKey: {key}\nDecrypted: [{decrypted}]\nOriginal: [{original}]\nCorrect? {decrypted == original}')