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

def encrypt(encoded, encoded_key):
    encrypted = ''

    for idx, char in enumerate(encoded):
        key_value = int(encoded_key[idx % len(encoded_key)])
        encrypted += f'{(int(char) + key_value) % 10}'

    return encrypted

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

key = '20260929'
message = '580647'
encrypted = encrypt(message, key)
decrypted = decrypt(encrypted, key)
print(f'Message: {message}')
print(f'Key: {key}')
print(f'Encrypted: {encrypted}')
print(f'Decrypted: {decrypted}')
