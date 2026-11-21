import csv

alphabet = 'абвгґдеєжзиіїйклмнопрстуфхцчшщьюя'

def decrypt(encrypted_message, key):
    decrypted = ''
    count = 0
    # temp_flag = True;
    for char in encrypted_message:
        if char.lower() not in alphabet:
            decrypted += char
            continue
        # if count == 196 and temp_flag:
        #     count -= 1
        #     temp_flag = False
        key_char_index = alphabet.find(key[count % len(key)].lower())
        char_index = alphabet.find(char.lower())
        target = (char_index - key_char_index) % len(alphabet)
        decrypted_char = alphabet[target]
        decrypted += decrypted_char.upper() if char.isupper() else decrypted_char
        count += 1
    return decrypted

with open('2.csv', newline='') as csvfile:
    spamreader = csv.reader(csvfile, delimiter='|')
    next(spamreader, None)

    for row in spamreader:
        encrypted = row[0].strip()
        key = row[1]
        original = row[2].strip()
        decrypted = decrypt(encrypted, key)
        print(f'\nEncrypted: [{encrypted}]\nKey: {key}\nDecrypted: [{decrypted}]\nOriginal: [{original}]\nCorrect? {decrypted == original}')