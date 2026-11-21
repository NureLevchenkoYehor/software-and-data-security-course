import csv

alphabet = 'абвгґдеєжзиіїйклмнопрстуфхцчшщьюя'

straddling_checkerboard = {
    '': 'аитесно',
    '8': 'бвгґдєжзії',
    '9': 'йклмпруфхц',
    '0': 'чшщьюя '
}

def encode(text):
    encoded = ''
    for char in text:
        for key, row in straddling_checkerboard.items():
            if char in row:
                encoded += f'{key}{row.find(char) + 1}'
                continue
    return encoded

def decrypt(encrypted_message, encoded_key):
    decrypted = ''

    for idx, char in enumerate(encrypted_message):
        key_value = int(encoded_key[idx % len(encoded_key)])
        decrypted += f'{((int(char) + 10) - key_value) % 10}'

    return decrypted

def decode(encoded_text):
    decoded_text = ''
    buffer = ''
    for char in encoded_text:
        if char in straddling_checkerboard and buffer == '':
            buffer = char
            continue

        decoded_text += straddling_checkerboard[buffer][int(char) - 1]
        buffer = ''
    return decoded_text

with open('4.csv', newline='') as csvfile:
    spamreader = csv.reader(csvfile, delimiter='|')
    next(spamreader, None)

    for row in spamreader:
        encrypted = row[0].strip()
        key = row[1]
        decrypted = decrypt(encrypted, encode(key))
        print(f'\nEncrypted: {encrypted}')
        print(f'Key: {key} ({encode(key)})')
        print(f'Decrypted: {decrypted}')
        print(f'Decoded: {decode(decrypted)}')