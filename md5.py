import sys
import hashlib

if __name__ == '__main__':

    folder_1 = sys.argv[0]
    folder_2 = sys.argv[1]

    for arg in sys.argv[2:]:

        with open(f'{folder_1}/{arg}', 'rb') as f1:
            md5_1 = hashlib.md5(f1.read()).hexdigest()

        with open(f'{folder_2}/{arg}', 'rb') as f2:
            md5_2 = hashlib.md5(f1.read()).hexdigest()

        assert md5_1 == md5_2

# ls *.py | xargs python md5.py <folder_1> <folder_2>
