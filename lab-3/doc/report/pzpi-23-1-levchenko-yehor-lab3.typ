#import "@local/nure:0.3.0": *
#import style: spacing

#let w = work(
  ..toml("doc.toml"),
)

#set document(..w.document)
#show: style.dstu.with(skip: 1)

#report.title-page(w)

// Автоматична нумерація рядків у лістингах із вказаною мовою.
// Блоки без мови (дерева каталогів, виведення програм) лишаються без номерів.
#show raw.where(block: true): it => {
  if it.lang == none { return it }
  show raw.line: line => {
    box(width: 1.5em, align(right, str(line.number)))
    h(0.75em)
    line.body
  }
  it
}

#title-heading(w)
#v(-spacing)

== Мета роботи
Метою роботи є ознайомлення з можливостями криптографічних хеш-функцій при організації контролю цілісності цифрових об'єктів та отримання навичок їх використання.

== Хід роботи
#v(-spacing)
=== Теоретичні відомості
Хеш-функція -- це обчислювально ефективна функція, що відображає двійковий рядок довільної довжини в двійковий рядок фіксованої довжини $m$, який називається згорткою, хеш-значенням або дайджестом @nure_method. Хеш-функція називається криптографічною, якщо вона односпрямована (за дайджестом практично неможливо відновити вхідні дані), вільна від колізій (обчислювально складно знайти два повідомлення з однаковим дайджестом) і має властивість повного перемішування: зміна хоча б одного біта вхідних даних змінює в середньому половину бітів дайджесту @stallings_crypto.

Криптографічну хеш-функцію можна побудувати на основі симетричного блокового алгоритму. Повідомлення $M$ розбивається на блоки $M_i$, які по черзі обробляються функцією стиснення
$ H_0 = I_H, quad H_i = E_A (B) plus.o C, $ <general-scheme>
#par(first-line-indent: 0pt)[де $I_H$ -- початкове значення, $E$ -- блоковий шифр, а $A$ (ключ), $B$ (вхід шифратора) і $C$ можуть приймати значення $M_i$, $H_(i-1)$, $M_i plus.o H_(i-1)$ або бути константами @nure_method.]

// dstu-ignore-next-line: citation-order
З $4^3 = 64$ варіантів схеми лише 12 є безпечними @preneel_1993.

Завдання вимагає, щоб зміна будь-якого байту тексту призводила до зміни не менше 30% результату хеш-функції, проте методичні вказівки не пояснюють, як цю вимогу перевірити. Для цього використано лавинний тест. Лавинний ефект (avalanche effect) -- це і є властивість повного перемішування. Його формалізує суворий лавинний критерій (Strict Avalanche Criterion) @webster_tavares: при інверсії будь-якого вхідного біта кожен вихідний біт має змінюватися з імовірністю $1 slash 2$. Тоді кількість змінених бітів $n$-бітного дайджесту $d$ має біноміальний розподіл $d tilde B(n, 1 slash 2)$, а в середньому змінюється $n slash 2$ бітів, тобто 50%.

Лавинний тест полягає в багаторазовому повторенні випробування:
- згенерувати випадкове повідомлення $M$ і обчислити $h(M)$;
- замінити один випадковий байт повідомлення на інше значення, отримавши $M'$;
- обчислити частку змінених бітів $d slash n$, де $d$ -- кількість одиничних бітів у $h(M) plus.o h(M')$.

За результатами обчислюються середня частка змінених бітів (для якісної функції близько 50%) та частка випробувань, у яких змінилося не менше 30% бітів. Друга величина для коротких дайджестів не може дорівнювати 100%: якщо зафіксувати всі байти повідомлення, крім одного, то 256 значень цього байту відображаються лише у $2^n$ значень дайджесту, тож при $n < 8$ деякі заміни байту неминуче залишають дайджест незмінним. Тому вимогу завдання слід розуміти статистично. Очікувані для ідеальної функції значення наведено в @expected-table[таблиці].

#tab(
  caption: [Очікувана частка випробувань зі зміною не менше 30% бітів для ідеальної функції],
  columns: (1fr, 1.5fr, 2fr),
  header: ([Біт дайджесту $n$], [Мінімум змінених бітів], [Очікувана частка]),
  label: <expected-table>,
  [2], [1], [$1 - 1 slash 4 = 75%$],
  [4], [2], [$1 - 5 slash 16 approx 69%$],
  [8], [3], [$1 - 37 slash 256 approx 86%$],
  [64], [20], [$approx 99.9%$],
)

=== Архітектура програмного забезпечення
Застосунок побудовано за клієнт-серверною архітектурою, аналогічно до лабораторної роботи №2:
- серверна частина реалізована мовою Python з використанням фреймворку FastAPI @fastapi_docs, бібліотек `cryptography` (ключі RSA) та `python-docx` (генерація документа Word). Вона містить хеш-функцію, лавинний тест, пошук колізій, генерацію документів, цифровий підпис та консольну утиліту;
- клієнтська частина (веб-інтерфейс) розроблена мовою TypeScript з використанням середовища виконання Bun, бібліотеки React та компонентів Material UI.

Структура каталогів розробленого проєкту:

```
.
├── client/
│   ├── README.md                     // Інструкція запуску клієнта
│   └── src/
│       ├── App.tsx                   // Кореневий компонент React
│       ├── components/
│       │   ├── BitsSelect.tsx        // Вибір довжини дайджесту
│       │   ├── DigestCard.tsx        // Картка з дайджестом файла
│       │   ├── DigestPanel.tsx       // Порівняння дайджестів
│       │   ├── FilePicker.tsx        // Вибір файла
│       │   └── SignaturePanel.tsx    // Підпис і перевірка підпису
│       ├── lib/
│       │   └── api.ts                // Запити до серверного API
│       └── pages/
│           └── MainPage.tsx          // Головна сторінка застосунку
├── doc/                              // Методичні вказівки та звіт
├── README.md                         // Загальний опис роботи
├── samples/
│   ├── original/                     // Вихідні документи
│   ├── modified/                     // Змінені документи
│   └── collided/                     // Документи з колізією
└── server/
    ├── bin/
    │   ├── cli.py                    // Консольна утиліта
    │   ├── generate_keys.py          // Генерація пари ключів RSA
    │   └── main.py                   // Точка входу сервера FastAPI
    ├── pyproject.toml                // Залежності серверного пакета
    ├── README.md                     // Інструкція запуску сервера
    └── src/
        └── lab3_server/
            ├── app.py                // Маршрути API
            ├── avalanche.py          // Лавинний тест
            ├── collide.py            // Пошук колізії для файла
            ├── des.py                // DES з лабораторної роботи №1
            ├── des_constants.py      // Стандартні константи DES
            ├── keys.py               // Генерація пари ключів RSA
            ├── samples.py            // Генерація документів
            ├── signature.py          // Цифровий підпис дайджесту
            └── tinyhash.py           // Хеш-функція TinyHash
```

Усі завдання, крім веб-інтерфейсу, доступні через консольну утиліту `bin/cli.py`, команди якої наведено в @cli-table[таблиці]. Довжина дайджесту задається параметром `-b` (`--bits`) зі значеннями 2, 4 або 8 (за замовчуванням 8).

#tab(
  caption: [Команди консольної утиліти],
  columns: (1fr, 4fr),
  header: ([Команда], [Призначення]),
  label: <cli-table>,
  [`hash`], [Обчислення дайджестів одного чи кількох файлів],
  [`avalanche`], [Лавинний тест хеш-функції],
  [`collide`], [Зміна файла так, щоб його дайджест збігся з дайджестом іншого],
  [`samples`], [Генерація вихідних і змінених документів та пошук колізій для них],
  [`sign`], [Цифровий підпис дайджесту файла],
  [`verify`], [Перевірка цифрового підпису дайджесту файла],
)

=== Алгоритм хеш-функції
Хеш-функцію (умовна назва -- TinyHash) побудовано за узагальненою схемою згідно з @general-scheme[формулою]. Як шифратор $E$ використано алгоритм DES @fips_46_3, реалізований у лабораторній роботі №1. DES має 64-бітний блок і 64-бітний ключ, тому і блок повідомлення $M_i$, і попереднє хеш-значення $H_(i-1)$ мають однакову довжину та можуть використовуватися як вхід шифратора і як ключ. Модулі `des.py` і `des_constants.py` скопійовано з лабораторної роботи №1 без змін, окрім шляху імпорту. До `des.py` додано лише функцію `encrypt_block`, яка виконує ті самі кроки, що й функція `encrypt` (початкова перестановка, 16 раундів мережі Фейстеля, кінцева перестановка), але для одного 64-бітного блоку без доповнення. Правильність перевірено на класичному тестовому векторі DES: ключ `133457799BBCDFF1`, блок `0123456789ABCDEF`, результат `85E813540F0AB405`.

Зі змінних схеми обрано $A = H_(i-1)$, $B = M_i$, $C = M_i plus.o H_(i-1)$, тож функція стиснення має вигляд
$ H_i = "DES"_(H_(i-1)) (M_i) plus.o M_i plus.o H_(i-1). $
Цей варіант відомий як схема Міягучі -- Пренеля (Miyaguchi--Preneel) і належить до безпечних варіантів загальної схеми @menezes_hac.

Повне обчислення дайджесту складається з таких кроків:
- початкове значення: $H_0 = I_H = mono("0x0123456789ABCDEF")$ (довільна фіксована константа);
- доповнення: до повідомлення дописується байт `0x80`, мінімально необхідна кількість нульових байтів і 64-бітна довжина повідомлення в бітах, так щоб загальна довжина стала кратною 8 байтам. Запис довжини гарантує, що повідомлення різної довжини не матимуть однакового доповненого вигляду;
- обробка блоків: доповнене повідомлення розбивається на 64-бітні блоки $M_1, dots, M_k$, кожен з яких по черзі обробляється функцією стиснення;
- згортання: 64-бітне значення $H_k$ розбивається на частини по $n$ біт (2, 4 або 8), які поєднуються операцією XOR. Наприклад, для $n = 8$ результатом є XOR усіх восьми байтів $H_k$. Таке згортання враховує кожен біт $H_k$, тож лавинний ефект 64-бітного значення переноситься на короткий дайджест.

Клас `TinyHash` дозволяє подавати дані частинами (метод `update`) та копіювати проміжний стан (метод `copy`), аналогічно до класів стандартного модуля `hashlib`. Це використовується під час пошуку колізій. Варто зазначити, що DES ігнорує біти парності ключа, тому 8 біт $H_(i-1)$ не впливають на ключ шифратора, проте вони не втрачаються, оскільки $H_(i-1)$ також входить у результат через доданок $C$.

Повний програмний код хеш-функції наведено у @app-server[додатку], а код клієнтської частини (веб-інтерфейсу) -- у @app-client[додатку].

=== Результати лавинного тесту
Лавинний тест реалізовано у модулі `avalanche.py`. Кожне випробування генерує випадкове повідомлення довжиною від 16 до 512 байт і замінює в ньому один випадковий байт. Для обох версій повідомлення обчислюється 64-бітне значення $H_k$, яке згортається до 2, 4 і 8 біт. Рядок для 64 біт показує властивості самої функції стиснення до згортання. Результат виконання команди `python bin/cli.py avalanche --seed 1`:

```
Trials: 300, one random byte changed per trial
Bits | Mean changed |  Trials >= 30%
-------------------------------------
   2 |       51.33% |         75.33%
   4 |       52.83% |         73.67%
   8 |       51.17% |         89.00%
  64 |       50.14% |        100.00%
```

Середня частка змінених бітів для всіх довжин дайджесту становить близько 50%, що відповідає ідеальній хеш-функції і значно перевищує вимогу в 30%. Частки випробувань, у яких змінилося не менше 30% бітів (75%, 74%, 89%, 100%), близькі до теоретичних значень з @expected-table[таблиці] (75%, 69%, 86%, 99.9%). Отже, вимогу завдання 1 виконано.

=== Документи та пошук колізій
Для дослідження модуль `samples.py` генерує три документи у вихідній (`samples/original/`) і зміненій (`samples/modified/`) версіях, перелік яких наведено в @samples-table[таблиці]. Зображення формується без сторонніх бібліотек: пікселі стискаються `zlib` і записуються у фрагменти (chunks) PNG `IHDR`, `IDAT` та `IEND` @png_spec.

#tab(
  caption: [Документи для дослідження],
  columns: (1fr, 2.2fr, 2fr),
  header: ([Файл], [Вміст], [Зміна]),
  label: <samples-table>,
  [`doc.docx`], [Платіжне доручення (документ Word)], [Сума до сплати 1~000 → 9~000 UAH],
  [`source.py`], [Програма-калькулятор депозиту мовою Python], [Відсоткова ставка 0.05 → 0.50],
  [`image.png`], [Зображення 128×128 (градієнт із квадратом)], [Колір квадрата синій → червоний],
)

Дайджести вихідних документів (команда `hash`):

```
$ python bin/cli.py hash -b 2 ../samples/original/*
      10  0x2   ../samples/original/doc.docx
      00  0x0   ../samples/original/image.png
      11  0x3   ../samples/original/source.py
$ python bin/cli.py hash -b 4 ../samples/original/*
    1000  0x8   ../samples/original/doc.docx
    1111  0xf   ../samples/original/image.png
    0011  0x3   ../samples/original/source.py
$ python bin/cli.py hash -b 8 ../samples/original/*
11100110  0xe6  ../samples/original/doc.docx
01011010  0x5a  ../samples/original/image.png
01100101  0x65  ../samples/original/source.py
```

Пошук колізії реалізовано у модулі `collide.py`. До зміненого документа додається 16-символьне число (nonce) у місце, яке формат файла ігнорує, тобто таке, що не впливає на відображення чи виконання документа (@carriers-table[таблиця]).

#tab(
  caption: [Місце розміщення nonce у документах різних форматів],
  columns: (1fr, 4fr),
  header: ([Формат], [Місце для nonce]),
  label: <carriers-table>,
  [`.docx`], [Коментар ZIP-архіву в кінці запису End of Central Directory @zip_appnote, який Word ігнорує],
  [`.png`], [Текстовий фрагмент `tEXt` перед завершальним фрагментом `IEND` @png_spec],
  [вихідний код], [Коментар в останньому рядку (`#`, `//` або `--` залежно від мови)],
)

Значення nonce послідовно перебираються (`0000000000000000`, `0000000000000001`, …), доки дайджест зміненого документа не збіжеться з цільовим. Кожна спроба дає збіг з імовірністю $2^(-n)$, тому очікувана кількість спроб дорівнює $2^n$: 4, 16 і 256 для 2, 4 і 8 біт відповідно. Оскільки nonce завжди розташований у кінці файла, стан хеш-функції для незмінної частини файла обчислюється один раз, а для кожної спроби копіюється (`TinyHash.copy`) і хешуються лише кілька останніх блоків.

Результат автоматичного пошуку колізій для трьох документів (команда `samples`, 8 біт):

```
File       | Original | Modified | Collided | Tries
----------------------------------------------------
doc.docx   | 11100110 | 11010100 | 11100110 |    86
source.py  | 01100101 | 01111001 | 01100101 |   250
image.png  | 01011010 | 10011001 | 01011010 |   204
```

Документи з підібраним дайджестом збережено у `samples/collided/`. Усі вони залишаються коректними: документ Word відкривається та містить змінену суму, зображення відображається з червоним квадратом, а програма виконується. Наприклад, останній рядок `samples/collided/source.py` має вигляд `# nonce: 00000000000000f9`. Для довільної пари файлів використовується команда `collide`:

```
$ python bin/cli.py collide -b 4 ../samples/original/image.png \
    ../samples/modified/image.png -o collided.png
Nonce: 0000000000000018, tries: 25
    1111  0xf   ../samples/original/image.png
    0000  0x0   ../samples/modified/image.png
    1111  0xf   collided.png
```

Документ Word є ZIP-архівом, який зберігає час створення файлів, тому при повторній генерації документів дайджест `doc.docx` змінюється, навіть якщо текст залишився тим самим.

=== Веб-інтерфейс та цифровий підпис дайджесту
Сервер надає програмні інтерфейси, наведені в @endpoints-table[таблиці]. Файли передаються у форматі `multipart/form-data`, довжина дайджесту -- у полі `bits`.

#tab(
  caption: [Специфікація API ендпоінтів сервера],
  columns: (1fr, 2fr, 5fr),
  header: ([Метод], [Шлях], [Призначення]),
  label: <endpoints-table>,
  [POST], [/api/digest], [Обчислення дайджесту завантаженого файла],
  [POST], [/api/sign], [Обчислення дайджесту файла та його підпис],
  [POST], [/api/verify], [Перевірка підпису (поле `signature`) для дайджесту файла],
  [GET], [/api/public-key], [Відкритий ключ RSA ($n$, $e$)],
)

Пара ключів RSA-2048 з відкритою експонентою $e = 65537$ генерується утилітою `bin/generate_keys.py`, як у лабораторній роботі №2, і зберігається у форматі PEM. Підпис обчислюється безпосередньо над значенням дайджесту $h$:
$ s = h^d mod n, $
а перевірка полягає в порівнянні $s^e mod n$ з $h$. Оскільки підписується лише дайджест, підпис дійсний для будь-якого документа з тим самим дайджестом. Це демонструє, що надійність цифрового підпису не може бути вищою за стійкість хеш-функції до колізій:

```
$ python bin/cli.py sign ../samples/original/source.py -o sig.txt
Digest:    01100101 (0x65)
Signature: 1b215224b40a866795cf62923b2569c2…
$ python bin/cli.py verify ../samples/collided/source.py sig.txt
Digest: 01100101 (0x65)
Signature is VALID
$ python bin/cli.py verify ../samples/modified/source.py sig.txt
Digest: 01111001 (0x79)
Signature is INVALID
```

Веб-інтерфейс містить перемикач довжини дайджесту та дві вкладки. Вкладку «Digest», яка обчислює дайджест завантаженого файла і порівнює його з дайджестом другого файла або з введеним еталонним дайджестом, показано на @fig-digest-form[рисунку].

#figure(
  image("assets/digest-form.png", width: 75%),
  caption: [Вкладка обчислення та порівняння дайджестів],
) <fig-digest-form>

Результат обчислення дайджесту вихідного документа source.py наведено на @fig-digest[рисунку].

#figure(
  image("assets/source-py-digest.png", width: 75%),
  caption: [Дайджест вихідного документа source.py],
) <fig-digest>

Для двох копій вихідного документа дайджести збігаються (@fig-compare-success[рисунок]).

#figure(
  image("assets/source-py-digest-compare-success.png", width: 75%),
  caption: [Порівняння дайджестів двох копій вихідного документа source.py],
) <fig-compare-success>

Для вихідного та зміненого документа дайджести відрізняються, тобто цілісність порушено (@fig-compare-fail[рисунок]).

#figure(
  image("assets/source-py-digest-compare-fail.png", width: 75%),
  caption: [Порівняння дайджестів вихідного та зміненого документа source.py],
) <fig-compare-fail>

Для документа з підібраним nonce дайджест знову збігається з дайджестом вихідного, хоча розмір і вміст файла інші (@fig-collided[рисунок]).

#figure(
  image("assets/source-py-digest-collided-compare-success.png", width: 75%),
  caption: [Порівняння дайджестів вихідного документа source.py та документа з підібраним дайджестом],
) <fig-collided>

Вкладку «RSA signature», яка підписує дайджест файла та перевіряє підпис, показано на @fig-signature-form[рисунку].

#figure(
  image("assets/signature-form.png", width: 75%),
  caption: [Вкладка підпису та перевірки підпису дайджесту],
) <fig-signature-form>

Результат підпису дайджесту вихідного зображення image.png наведено на @fig-signature-made[рисунку].

#figure(
  image("assets/signature-made.png", width: 75%),
  caption: [Підпис дайджесту вихідного зображення image.png],
) <fig-signature-made>

Перевірка цього підпису для вихідного зображення завершується успішно (@fig-signature-verified[рисунок]).

#figure(
  image("assets/signature-verified.png", width: 75%),
  caption: [Перевірка підпису для вихідного зображення],
) <fig-signature-verified>

Для зміненого зображення підпис недійсний, оскільки дайджест відрізняється (@fig-signature-not-verified[рисунок]).

#figure(
  image("assets/signature-not-verified.png", width: 75%),
  caption: [Перевірка підпису для зміненого зображення],
) <fig-signature-not-verified>

На @fig-signature-collided[рисунку] підпис сформовано для документа source.py з підібраним дайджестом: він збігається з підписом вихідного документа, наведеним вище (`1b215224b40a8667…`), оскільки підписується лише дайджест, а підпис RSA без доповнення детермінований. Отже, підпис вихідного документа дійсний і для документа з підібраним дайджестом.

#figure(
  image("assets/source-signature-original-colided-success.png", width: 75%),
  caption: [Підпис і перевірка підпису для документа source.py з підібраним дайджестом],
) <fig-signature-collided>

== Висновки
У результаті виконання лабораторної роботи було:
- розроблено хеш-функцію з довжиною результату 2, 4 або 8 біт на основі блокового алгоритму DES з лабораторної роботи №1 за схемою Міягучі -- Пренеля, яка є одним із варіантів узагальненої схеми з методичних вказівок;
- за допомогою лавинного тесту перевірено, що зміна одного байту повідомлення змінює в середньому близько 50% бітів дайджесту, що перевищує вимогу в 30%;
- створено три документи (документ Word, вихідний код мовою Python, зображення PNG), обчислено їх дайджести та внесено до них зміни;
- реалізовано програму для автоматичного пошуку колізії, яка підбирає службові дані в частині файла, що ігнорується його форматом, так що дайджест зміненого документа збігається з дайджестом вихідного. Для 8-бітного дайджесту колізію знайдено за 86--250 спроб, що відповідає очікуваним $2^8 = 256$ спробам;
- реалізовано веб-інтерфейс для завантаження файлів та перевірки дайджесту, а також цифровий підпис дайджесту на основі RSA.

Робота показала, що контроль цілісності за допомогою хеш-функції надійний лише тоді, коли довжина дайджесту достатня для стійкості до колізій. Для коротких дайджестів змінений документ з тим самим дайджестом знаходиться за кілька сотень спроб, а цифровий підпис такого дайджесту залишається дійсним для підробленого документа.

== Контрольні запитання
1\. Поняття хеш-функції.

Хеш-функція -- це обчислювально ефективна функція $h$, яка відображає двійковий рядок довільної довжини в рядок фіксованої довжини $m$, що називається згорткою, хеш-значенням або дайджестом. Хеш-функція детермінована: однакові вхідні дані завжди дають однаковий дайджест. Оскільки множина вхідних повідомлень нескінченна, а множина дайджестів містить лише $2^m$ елементів, різні повідомлення неминуче можуть мати однаковий дайджест.

Більшість практичних хеш-функцій побудовано за схемою Меркла -- Дамгора: повідомлення доповнюється й розбивається на блоки фіксованої довжини, які по черзі обробляються функцією стиснення $H_i = f(H_(i-1), M_i)$ @menezes_hac. За цією схемою побудовано і хеш-функцію в цій роботі.

2\. Поняття криптографічної хеш-функції.

Криптографічна хеш-функція -- це хеш-функція, яка додатково має такі властивості:
- односпрямованість (стійкість до знаходження прообразу): за дайджестом $y$ обчислювально неможливо знайти повідомлення $M$, для якого $h(M) = y$;
- стійкість до знаходження другого прообразу: для заданого $M$ обчислювально неможливо знайти $M' != M$, для якого $h(M') = h(M)$;
- стійкість до колізій: обчислювально неможливо знайти будь-яку пару $M != M'$, для якої $h(M) = h(M')$;
- повне перемішування (лавинний ефект): зміна одного біта вхідних даних змінює в середньому половину бітів дайджесту.

Сучасними криптографічними хеш-функціями є SHA-2 (SHA-256, SHA-512) та SHA-3. Функції MD5 та SHA-1 вважаються зламаними, оскільки для них практично знайдено колізії.

3\. Поняття колізії.

Колізія -- це ситуація, коли два різні повідомлення $M != M'$ мають однаковий дайджест $h(M) = h(M')$. Колізії існують для будь-якої хеш-функції, оскільки кількість можливих повідомлень більша за кількість дайджестів, тому мова йде лише про складність їх знаходження.

Для ідеальної $m$-бітної хеш-функції підбір другого повідомлення з наперед заданим дайджестом потребує в середньому $2^m$ спроб, а знаходження будь-якої пари повідомлень з однаковим дайджестом -- лише близько $2^(m slash 2)$ спроб завдяки парадоксу днів народження. Саме тому дайджести сучасних функцій мають довжину 256 біт і більше. У цій роботі дайджест має лише 2--8 біт, тому колізію для документа вдається знайти за кілька сотень спроб.

4\. Поняття ключової хеш-функції.

Ключова хеш-функція -- це криптографічна хеш-функція, результат якої залежить не лише від повідомлення, але й від секретного ключа $K$. Її значення називають кодом автентифікації повідомлення (MAC) або імітовставкою. Без знання ключа неможливо ні обчислити правильний MAC для нового повідомлення, ні перевірити наявний, тому MAC забезпечує не лише цілісність, а й автентичність повідомлення: його міг сформувати лише власник ключа.

Найпоширенішими конструкціями є HMAC, який будується на основі звичайної хеш-функції:
$ "HMAC"(K, M) = h((K plus.o "opad") || h((K plus.o "ipad") || M)), $
та CBC-MAC, який будується на основі блокового шифру (останній блок шифротексту в режимі CBC). На відміну від цифрового підпису, MAC використовує симетричний ключ, тобто перевірити його може лише сторона, яка знає той самий ключ.

5\. Властивості односпрямованості і повного перемішування.

Односпрямованість означає, що дайджест обчислюється легко, а зворотна операція -- відновлення вхідного повідомлення або будь-якого іншого повідомлення з тим самим дайджестом -- обчислювально неможлива. Тобто для заданого $y$ знайти $M$ таке, що $h(M) = y$, можна лише повним перебором, який для довгих дайджестів практично нездійсненний. Ця властивість дозволяє, наприклад, зберігати хеші паролів замість самих паролів.

Повне перемішування (лавинний ефект) означає, що зміна хоча б одного біта вхідної послідовності змінює в середньому половину бітів дайджесту, причому кожен біт дайджесту змінюється з імовірністю $1 slash 2$ незалежно від інших @webster_tavares. Завдяки цьому схожі повідомлення мають зовсім не схожі дайджести, і за дайджестами неможливо зробити висновок про те, наскільки та де повідомлення відрізняються. Цю властивість перевіряють лавинним тестом, описаним вище.

6\. Можливості побудови хеш-функцій на основі симетричних блокових алгоритмів.

Найпростіший спосіб -- зашифрувати повідомлення блоковим алгоритмом у режимі CBC або CFB з фіксованим ключем і вектором ініціалізації, а останній блок шифротексту використати як хеш-значення. Такий підхід не завжди дає безпечну односпрямовану хеш-функцію, але завжди дає код автентифікації (CBC-MAC), якщо ключ секретний.

Більш безпечний підхід -- функція стиснення виду $H_i = E_A (B) plus.o C$, де $A$, $B$, $C$ обираються з $M_i$, $H_(i-1)$, $M_i plus.o H_(i-1)$ та константи. З $4^3 = 64$ можливих варіантів лише 12 є безпечними @preneel_1993. Найвідоміші з них:
- схема Девіса -- Маєра (Davies--Meyer): $H_i = E_(M_i) (H_(i-1)) plus.o H_(i-1)$. Ця схема лежить в основі функцій стиснення MD5, SHA-1 та SHA-2, у яких блоковий шифр спеціально спроєктовано для хешування;
- схема Матіаса -- Маєра -- Осеаса (Matyas--Meyer--Oseas): $H_i = E_(H_(i-1)) (M_i) plus.o M_i$;
- схема Міягучі -- Пренеля (Miyaguchi--Preneel): $H_i = E_(H_(i-1)) (M_i) plus.o M_i plus.o H_(i-1)$. Ця схема використовується у функції Whirlpool та в цій лабораторній роботі (з шифром DES).

Оскільки довжина хеш-значення в таких схемах дорівнює довжині блоку, для 64-бітних шифрів на кшталт DES вона замала для стійкості до колізій (близько $2^32$ спроб). Тому існують схеми з подвійною довжиною хеш-значення, наприклад MDC-2, а сучасні блокові шифри (AES) мають 128-бітний блок.

7\. Використання хеш-функцій при вирішенні завдання контролю цілісності.

Для контролю цілісності в певний момент часу обчислюється еталонний дайджест $h(M)$ даних $M$, цілісність якого забезпечується організаційними або технічними заходами (наприклад, він зберігається окремо від даних або публікується на іншому ресурсі). Для перевірки обчислюється дайджест поточних даних $h(M')$ і порівнюється з еталонним: якщо $h(M) = h(M')$, дані вважаються цілісними, інакше цілісність порушено @nure_method.

Прикладами такого використання є контрольні суми (SHA-256) для файлів дистрибутивів програмного забезпечення, системи контролю цілісності файлів (AIDE, Tripwire) та ідентифікатори об'єктів у системі контролю версій Git. Щоб зловмисник не міг підмінити разом із даними й еталонний дайджест, використовують ключову хеш-функцію (MAC) або цифровий підпис дайджесту. Як показано в цій роботі, такий контроль надійний лише тоді, коли хеш-функція стійка до колізій: для 8-бітного дайджесту змінений документ із тим самим дайджестом знаходиться за кілька сотень спроб.

#bib(path("bibl.yml"), style: "3008")

#show: style.appendices

= Програмний код серверної частини <app-server>
// dstu-ignore-next-line: heading-orphan
== Хеш-функція TinyHash (src/lab3_server/tinyhash.py) <srv-tinyhash>
```python
"""TinyHash: a hash function with a 2, 4 or 8 bit digest built on DES.

Scheme from the lab's theory (fig. 3.1):

    H_0 = I_H
    H_i = E_A(B) xor C

with A = H_{i-1} (key), B = M_i (encrypted block), C = M_i xor H_{i-1}:

    H_i = DES_{H_{i-1}}(M_i) xor M_i xor H_{i-1}

The message is split into 64-bit blocks (the DES block size). The last block
is padded with 0x80, zeros and the message length. The final 64-bit H is
XOR-folded down to the requested number of bits.
"""

from __future__ import annotations

from lab3_server.des import encrypt_block

BLOCK_SIZE = 8  # bytes, DES block
SUPPORTED_BITS = (2, 4, 8)
INITIAL_VALUE = 0x0123456789ABCDEF  # I_H, any fixed constant


def fold(value: int, bits: int) -> int:
    """XOR all `bits`-wide pieces of a 64-bit value together."""
    mask = (1 << bits) - 1
    result = 0
    for shift in range(0, 64, bits):
        result ^= (value >> shift) & mask
    return result


def pad(length: int) -> bytes:
    """Padding for a message of `length` bytes: 0x80, zeros, 64-bit length in bits."""
    zeros = (BLOCK_SIZE - (length + 1 + 8) % BLOCK_SIZE) % BLOCK_SIZE
    return b"\x80" + b"\x00" * zeros + (length * 8).to_bytes(8, "big")


class TinyHash:
    """Hasher that can be fed data in parts (like hashlib)."""

    def __init__(self, data: bytes = b"", bits: int = 8) -> None:
        if bits not in SUPPORTED_BITS:
            raise ValueError(f"bits must be one of {SUPPORTED_BITS}, got {bits}")
        self.bits = bits
        self.h = INITIAL_VALUE
        self.buffer = b""  # bytes waiting for a full block
        self.length = 0
        self.update(data)

    def compress(self, block: bytes) -> None:
        m = int.from_bytes(block, "big")
        self.h = encrypt_block(m, self.h) ^ m ^ self.h

    def update(self, data: bytes) -> None:
        self.length += len(data)
        data = self.buffer + data
        full = len(data) - len(data) % BLOCK_SIZE
        for i in range(0, full, BLOCK_SIZE):
            self.compress(data[i : i + BLOCK_SIZE])
        self.buffer = data[full:]

    def copy(self) -> TinyHash:
        clone = TinyHash(bits=self.bits)
        clone.h, clone.buffer, clone.length = self.h, self.buffer, self.length
        return clone

    def hash64(self) -> int:
        """Final 64-bit H (before folding). Does not change the hasher."""
        h = self.copy()
        rest = h.buffer + pad(h.length)
        for i in range(0, len(rest), BLOCK_SIZE):
            h.compress(rest[i : i + BLOCK_SIZE])
        return h.h

    def intdigest(self) -> int:
        return fold(self.hash64(), self.bits)

    def bindigest(self) -> str:
        return format(self.intdigest(), f"0{self.bits}b")

    def hexdigest(self) -> str:
        return format(self.intdigest(), f"0{(self.bits + 3) // 4}x")


def tinyhash(data: bytes, bits: int = 8) -> int:
    return TinyHash(data, bits).intdigest()
```

// dstu-ignore-next-line: heading-orphan
== Модуль DES з функцією шифрування одного блоку (src/lab3_server/des.py) <srv-des>
```python
from collections.abc import Callable, Sequence

from lab3_server.des_constants import *

BITS_PER_BYTE = 8

RoundCallback = Callable[[int, int, int], None]


def list_int64_to_bytes(chunks: list[int]) -> bytes:
    return b"".join(
        chunk.to_bytes(BLOCK_SIZE_BYTES, byteorder="big") for chunk in chunks
    )


def bytes_to_list_int64(data: bytes) -> list[int]:
    return [
        int.from_bytes(data[i : i + BLOCK_SIZE_BYTES], byteorder="big")
        for i in range(0, len(data), BLOCK_SIZE_BYTES)
    ]


def permute(data: int, permutation: Sequence[int], total_input_bits: int = 64) -> int:
    result = 0
    for pos in permutation:
        shift_from = total_input_bits - pos
        bit = (data >> shift_from) & 1
        result = (result << 1) | bit
    return result


def substitute_6bit_with_4bit(data_6bit: int, substitution: Sequence[int]) -> int:
    msb = (data_6bit >> 5) & 1
    lsb = (data_6bit >> 0) & 1
    row = (msb << 1) | lsb
    col = (data_6bit >> 1) & 0b1111
    result_4 = substitution[(row << 4) | col]
    return result_4


def pad_bytes_pkcs5(data: bytes) -> bytes:
    padding_length = BLOCK_SIZE_BYTES - len(data) % BLOCK_SIZE_BYTES
    padding = bytes([padding_length]) * padding_length
    return data + padding


def unpad_bytes_pkcs5(data: bytes) -> bytes:
    padding_length = data[-1]
    return data[:-padding_length]


def left_rotate_28bit(value: int, shift: int) -> int:
    return ((value << shift) & 0x0FFFFFFF) | (value >> (28 - shift))


def generate_round_keys(key_64bit: int) -> list[int]:
    key_56bit = permute(key_64bit, PERMUTED_CHOICE_1)
    left_28bit = (key_56bit >> 28) & 0xFFFFFFF
    right_28bit = key_56bit & 0xFFFFFFF

    result = []
    for shift in SHIFT_SCHEDULE:
        right_28bit = left_rotate_28bit(right_28bit, shift)
        left_28bit = left_rotate_28bit(left_28bit, shift)
        concat_56bit = (left_28bit << 28) | right_28bit
        round_key_48bit = permute(concat_56bit, PERMUTED_CHOICE_2, total_input_bits=56)
        result.append(round_key_48bit)
    return result


def preprocess_message(raw: str) -> bytes:
    message_bytes = raw.encode(encoding="utf-8")
    return pad_bytes_pkcs5(message_bytes)


def feistel_function(right: int, round_key: int) -> int:
    expanded_48bit = permute(right, EXPANSION_FUNCTION, total_input_bits=32)
    xored_48bit = expanded_48bit ^ round_key

    sbox_output_32bit = 0
    for s_box_idx, s_box in enumerate(SUBSTITUTION_BOXES):
        chunk_6bit = (xored_48bit >> (42 - 6 * s_box_idx)) & 0b111111

        chunk_4bit = substitute_6bit_with_4bit(chunk_6bit, s_box)

        sbox_output_32bit = (sbox_output_32bit << 4) | chunk_4bit

    return permute(sbox_output_32bit, PERMUTATION, total_input_bits=32)


def encrypt(
    raw: str, master_key_64bit: int, on_round: RoundCallback | None = None
) -> list[int]:
    if master_key_64bit in INSECURE_KEYS:
        raise ValueError(f"Insecure key: {hex(master_key_64bit)} is not allowed in DES")
    message = preprocess_message(raw)
    round_keys = generate_round_keys(master_key_64bit)
    cipher: list[int] = []
    for chunk_offset in range(0, len(message), BLOCK_SIZE_BYTES):
        chunk_bytes = message[chunk_offset : chunk_offset + BLOCK_SIZE_BYTES]
        # NOTE: Check https://en.wikipedia.org/wiki/DES_supplementary_material for Big Endian order
        chunk_64bit = int.from_bytes(chunk_bytes, byteorder="big")

        chunk_64bit = permute(chunk_64bit, INITIAL_PERMUTATION)
        left_32bit = chunk_64bit >> 32
        right_32bit = chunk_64bit & 0xFFFFFFFF

        if on_round and chunk_offset == 0:
            on_round(0, left_32bit, right_32bit)

        for round_idx in range(TOTAL_ROUNDS):
            feistel_result_32bit = feistel_function(right_32bit, round_keys[round_idx])
            left_32bit, right_32bit = right_32bit, left_32bit ^ feistel_result_32bit
            if on_round and chunk_offset == 0:
                on_round(round_idx + 1, left_32bit, right_32bit)

        pre_output_64bit = (right_32bit << 32) | left_32bit
        cipher_chunk_64bit = permute(pre_output_64bit, FINAL_PERMUTATION)

        cipher.append(cipher_chunk_64bit)
    return cipher


def decrypt(cipher: list[int], master_key_64bit: int) -> str:
    round_keys = generate_round_keys(master_key_64bit)[::-1]
    message_chunks: list[int] = []
    for chunk_64bit in cipher:
        chunk_64bit = permute(chunk_64bit, INITIAL_PERMUTATION)
        left_32bit = chunk_64bit >> 32
        right_32bit = chunk_64bit & 0xFFFFFFFF

        for round_idx in range(TOTAL_ROUNDS):
            feistel_result_32bit = feistel_function(right_32bit, round_keys[round_idx])
            left_32bit, right_32bit = right_32bit, left_32bit ^ feistel_result_32bit

        pre_output_64bit = (right_32bit << 32) | left_32bit
        message_chunk_64bit = permute(pre_output_64bit, FINAL_PERMUTATION)

        message_chunks.append(message_chunk_64bit)
    message_bytes = list_int64_to_bytes(message_chunks)
    unpadded_bytes = unpad_bytes_pkcs5(message_bytes)
    return unpadded_bytes.decode(encoding="utf-8")


def encrypt_block(block_64bit: int, key_64bit: int) -> int:
    """Encrypt a single 64-bit block (no padding, no weak-key check).

    Same steps as `encrypt` above, but for one block given as an integer.
    """
    round_keys = generate_round_keys(key_64bit)

    block_64bit = permute(block_64bit, INITIAL_PERMUTATION)
    left_32bit = block_64bit >> 32
    right_32bit = block_64bit & 0xFFFFFFFF

    for round_idx in range(TOTAL_ROUNDS):
        feistel_result_32bit = feistel_function(right_32bit, round_keys[round_idx])
        left_32bit, right_32bit = right_32bit, left_32bit ^ feistel_result_32bit

    pre_output_64bit = (right_32bit << 32) | left_32bit
    return permute(pre_output_64bit, FINAL_PERMUTATION)
```

// dstu-ignore-next-line: heading-orphan
== Лавинний тест (src/lab3_server/avalanche.py) <srv-avalanche>
```python
"""Avalanche test: change one byte of a message, measure how many digest bits change."""

import random
from dataclasses import dataclass

from lab3_server.tinyhash import SUPPORTED_BITS, TinyHash, fold

THRESHOLD = 0.30


@dataclass
class AvalancheResult:
    bits: int
    mean_changed: float  # average share of changed digest bits
    share_over_threshold: float  # share of trials where >= 30% of bits changed


def avalanche(trials: int = 300, seed: int | None = None) -> list[AvalancheResult]:
    rng = random.Random(seed)
    widths = (*SUPPORTED_BITS, 64)
    changed = {w: 0 for w in widths}
    over = {w: 0 for w in widths}

    for _ in range(trials):
        message = bytearray(rng.randbytes(rng.randint(16, 512)))
        before = TinyHash(bytes(message)).hash64()

        pos = rng.randrange(len(message))
        message[pos] = (message[pos] + rng.randint(1, 255)) % 256
        after = TinyHash(bytes(message)).hash64()

        for w in widths:
            share = (fold(before, w) ^ fold(after, w)).bit_count() / w
            changed[w] += share
            over[w] += share >= THRESHOLD

    return [AvalancheResult(w, changed[w] / trials, over[w] / trials) for w in widths]
```

// dstu-ignore-next-line: heading-orphan
== Автоматичний пошук колізії (src/lab3_server/collide.py) <srv-collide>
```python
"""Automatic collision: adjust a modified file so its digest equals the target.

A fixed-width nonce is placed in a part of the file that its format ignores:

* .docx (ZIP)  - archive comment at the end of the End of Central Directory record
* .png         - a tEXt chunk inserted right before IEND
* text/source  - a trailing comment line

The nonce always sits at the end of the file, so the hash state of the prefix
is computed once and only the short tail is re-hashed for every candidate.
"""

import struct
import zlib
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

from lab3_server.tinyhash import TinyHash

NONCE_LEN = 16
MAX_TRIES = 1 << 20

Tail = Callable[[bytes], bytes]

COMMENT_PREFIXES = {
    ".py": b"#", ".sh": b"#", ".rb": b"#", ".toml": b"#", ".yml": b"#", ".yaml": b"#",
    ".c": b"//", ".h": b"//", ".cpp": b"//", ".cs": b"//", ".java": b"//", ".js": b"//",
    ".ts": b"//", ".tsx": b"//", ".go": b"//", ".rs": b"//", ".kt": b"//", ".swift": b"//",
    ".sql": b"--", ".lua": b"--", ".hs": b"--",
}


@dataclass
class CollisionResult:
    data: bytes
    digest: int
    tries: int
    nonce: bytes


def _split_docx(data: bytes) -> tuple[bytes, Tail]:
    eocd = data.rfind(b"PK\x05\x06")
    if eocd < 0 or len(data) - eocd < 22:
        raise ValueError("Not a ZIP/DOCX file: End of Central Directory not found.")
    # Comment length is the last field of the 22-byte EOCD record; drop any existing comment.
    prefix = data[: eocd + 20]
    return prefix, lambda nonce: struct.pack("<H", len(nonce)) + nonce


def _png_chunk(kind: bytes, payload: bytes) -> bytes:
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload))


def _split_png(data: bytes) -> tuple[bytes, Tail]:
    iend = data.rfind(b"IEND")
    if not data.startswith(b"\x89PNG\r\n\x1a\n") or iend < 4:
        raise ValueError("Not a PNG file: IEND chunk not found.")
    prefix = data[: iend - 4]
    iend_chunk = _png_chunk(b"IEND", b"")
    return prefix, lambda nonce: _png_chunk(b"tEXt", b"nonce\x00" + nonce) + iend_chunk


def _split_text(data: bytes, comment: bytes) -> tuple[bytes, Tail]:
    prefix = data if data.endswith(b"\n") or not data else data + b"\n"
    return prefix, lambda nonce: comment + b" nonce: " + nonce + b"\n"


def split_carrier(data: bytes, suffix: str) -> tuple[bytes, Tail]:
    """Return (prefix, make_tail) such that prefix + make_tail(nonce) is a valid file."""
    suffix = suffix.lower()
    if suffix == ".docx":
        return _split_docx(data)
    if suffix == ".png":
        return _split_png(data)
    if suffix in COMMENT_PREFIXES:
        return _split_text(data, COMMENT_PREFIXES[suffix])
    raise ValueError(f"Unsupported file type: '{suffix}' (use .docx, .png or source code).")


def collide(data: bytes, suffix: str, target: int, bits: int) -> CollisionResult:
    """Find a nonce so that the digest of the modified file equals `target`."""
    prefix, make_tail = split_carrier(data, suffix)
    base = TinyHash(prefix, bits)

    for i in range(MAX_TRIES):
        nonce = format(i, f"0{NONCE_LEN}x").encode()
        tail = make_tail(nonce)
        h = base.copy()
        h.update(tail)
        if h.intdigest() == target:
            return CollisionResult(prefix + tail, target, i + 1, nonce)

    raise RuntimeError(f"No collision found in {MAX_TRIES} tries.")


def collide_files(original: Path, modified: Path, output: Path, bits: int) -> CollisionResult:
    target = TinyHash(original.read_bytes(), bits).intdigest()
    result = collide(modified.read_bytes(), modified.suffix, target, bits)
    output.write_bytes(result.data)
    return result
```

// dstu-ignore-next-line: heading-orphan
== Генерація документів (src/lab3_server/samples.py) <srv-samples>
```python
"""Generate sample documents: original and modified versions of a .docx, a .py and a .png."""

import struct
import zlib
from pathlib import Path

from docx import Document

SOURCE_TEMPLATE = '''"""Simple deposit calculator."""

INTEREST_RATE = {rate}


def deposit(amount: float, years: int) -> float:
    for _ in range(years):
        amount *= 1 + INTEREST_RATE
    return round(amount, 2)


if __name__ == "__main__":
    print(deposit(10_000, 5))
'''


def make_docx(path: Path, amount: str) -> None:
    doc = Document()
    doc.add_heading("Payment order No. 42", level=1)
    doc.add_paragraph("Payer: LLC \"Example\".")
    doc.add_paragraph("Recipient: Kharkiv National University of Radio Electronics.")
    doc.add_paragraph(f"Amount to pay: {amount} UAH.")
    doc.add_paragraph("Purpose: tuition fee for the 2026/2027 academic year.")
    doc.save(str(path))


def make_source(path: Path, rate: str) -> None:
    path.write_text(SOURCE_TEMPLATE.format(rate=rate), encoding="utf-8")


def _png_chunk(kind: bytes, payload: bytes) -> bytes:
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload))


def make_png(path: Path, square_color: tuple[int, int, int], size: int = 128) -> None:
    """Gradient background with a coloured square in the middle (8-bit RGB)."""
    rows = []
    lo, hi = size // 4, size * 3 // 4
    for y in range(size):
        row = bytearray(b"\x00")  # filter type: none
        for x in range(size):
            if lo <= x < hi and lo <= y < hi:
                row += bytes(square_color)
            else:
                row += bytes((x * 255 // size, y * 255 // size, 160))
        rows.append(bytes(row))

    header = struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)
    data = (
        b"\x89PNG\r\n\x1a\n"
        + _png_chunk(b"IHDR", header)
        + _png_chunk(b"IDAT", zlib.compress(b"".join(rows), 9))
        + _png_chunk(b"IEND", b"")
    )
    path.write_bytes(data)


def generate(directory: Path) -> list[tuple[Path, Path]]:
    """Create original/ and modified/ sample files. Returns (original, modified) pairs."""
    original = directory / "original"
    modified = directory / "modified"
    original.mkdir(parents=True, exist_ok=True)
    modified.mkdir(parents=True, exist_ok=True)

    make_docx(original / "doc.docx", "1 000")
    make_docx(modified / "doc.docx", "9 000")
    make_source(original / "source.py", "0.05")
    make_source(modified / "source.py", "0.50")
    make_png(original / "image.png", (40, 120, 220))
    make_png(modified / "image.png", (220, 40, 40))

    names = ("doc.docx", "source.py", "image.png")
    return [(original / n, modified / n) for n in names]
```

// dstu-ignore-next-line: heading-orphan
== Цифровий підпис дайджесту (src/lab3_server/signature.py) <srv-signature>
```python
"""RSA digital signature of a TinyHash digest.

The key pair is a regular RSA-2048 key (PEM, generated by bin/generate_keys.py);
the signature itself is computed directly on the digest value:

    sign:   s = h^d mod n
    verify: s^e mod n == h
"""

from pathlib import Path

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa

SERVER_ROOT = Path(__file__).resolve().parents[2]
PRIVATE_KEY_PATH = SERVER_ROOT / "private_key.pem"
PUBLIC_KEY_PATH = SERVER_ROOT / "public_key.pem"


def load_private_key(path: Path = PRIVATE_KEY_PATH) -> rsa.RSAPrivateKey:
    key = serialization.load_pem_private_key(path.read_bytes(), password=None)
    if not isinstance(key, rsa.RSAPrivateKey):
        raise TypeError(f"{path} is not an RSA private key.")
    return key


def load_public_key(path: Path = PUBLIC_KEY_PATH) -> rsa.RSAPublicKey:
    key = serialization.load_pem_public_key(path.read_bytes())
    if not isinstance(key, rsa.RSAPublicKey):
        raise TypeError(f"{path} is not an RSA public key.")
    return key


def sign_digest(digest: int, private_key: rsa.RSAPrivateKey) -> int:
    numbers = private_key.private_numbers()
    return pow(digest, numbers.d, numbers.public_numbers.n)


def verify_digest(digest: int, signature: int, public_key: rsa.RSAPublicKey) -> bool:
    numbers = public_key.public_numbers()
    if not 0 <= signature < numbers.n:
        return False
    return pow(signature, numbers.e, numbers.n) == digest
```

// dstu-ignore-next-line: heading-orphan
== Модуль генерації ключів RSA (src/lab3_server/keys.py) <srv-keys>
```python
from pathlib import Path

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa

"""Generate and persist an RSA-2048 key pair."""
def generate_key_pair(
    private_key_path: Path,
    public_key_path: Path,
) -> tuple[bytes, bytes]:
    for key_path in (private_key_path, public_key_path):
        if key_path.exists():
            raise FileExistsError(
                f"{key_path} already exists; refusing to overwrite it."
            )

    private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    private_key_pem = private_key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )
    public_key_pem = private_key.public_key().public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    )

    private_key_path.write_bytes(private_key_pem)
    public_key_path.write_bytes(public_key_pem)

    return private_key_pem, public_key_pem
```

// dstu-ignore-next-line: heading-orphan
== Маршрути API (src/lab3_server/app.py) <srv-app>
```python
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from typing import Annotated

from fastapi import FastAPI, Form, HTTPException, Request, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from lab3_server.signature import load_private_key, sign_digest, verify_digest
from lab3_server.tinyhash import SUPPORTED_BITS, TinyHash


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    try:
        app.state.private_key = load_private_key()
    except FileNotFoundError as error:
        raise RuntimeError(
            "RSA private key is missing. Run `python bin/generate_keys.py`."
        ) from error
    app.state.public_key = app.state.private_key.public_key()
    yield


app = FastAPI(lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_methods=["*"],
    allow_headers=["*"],
)


class DigestResponse(BaseModel):
    name: str
    size: int
    bits: int
    digest: int
    binary: str
    hex: str


class SignResponse(DigestResponse):
    signature: str


class VerifyResponse(DigestResponse):
    valid: bool


class PublicKeyResponse(BaseModel):
    n: str
    e: int


async def digest_of(file: UploadFile, bits: int) -> DigestResponse:
    if bits not in SUPPORTED_BITS:
        raise HTTPException(status_code=400, detail=f"bits must be one of {SUPPORTED_BITS}.")
    data = await file.read()
    h = TinyHash(data, bits)
    return DigestResponse(
        name=file.filename or "",
        size=len(data),
        bits=bits,
        digest=h.intdigest(),
        binary=h.bindigest(),
        hex=h.hexdigest(),
    )


@app.post("/api/digest")
async def digest(file: UploadFile, bits: Annotated[int, Form()] = 8) -> DigestResponse:
    return await digest_of(file, bits)


@app.post("/api/sign")
async def sign(request: Request, file: UploadFile, bits: Annotated[int, Form()] = 8) -> SignResponse:
    result = await digest_of(file, bits)
    signature = sign_digest(result.digest, request.app.state.private_key)
    return SignResponse(**result.model_dump(), signature=format(signature, "x"))


@app.post("/api/verify")
async def verify(
    request: Request,
    file: UploadFile,
    signature: Annotated[str, Form()],
    bits: Annotated[int, Form()] = 8,
) -> VerifyResponse:
    result = await digest_of(file, bits)
    try:
        value = int(signature.strip().removeprefix("0x"), 16)
    except ValueError as error:
        raise HTTPException(status_code=400, detail="Signature must be a hex number.") from error
    valid = verify_digest(result.digest, value, request.app.state.public_key)
    return VerifyResponse(**result.model_dump(), valid=valid)


@app.get("/api/public-key")
async def public_key(request: Request) -> PublicKeyResponse:
    numbers = request.app.state.public_key.public_numbers()
    return PublicKeyResponse(n=format(numbers.n, "x"), e=numbers.e)
```

// dstu-ignore-next-line: heading-orphan
== Консольна утиліта (bin/cli.py) <srv-cli>
```python
import argparse
import sys
from pathlib import Path

SERVER_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SERVER_ROOT / "src"))

from lab3_server.avalanche import THRESHOLD, avalanche
from lab3_server.collide import collide_files
from lab3_server.samples import generate
from lab3_server.signature import load_private_key, load_public_key, sign_digest, verify_digest
from lab3_server.tinyhash import SUPPORTED_BITS, TinyHash

DEFAULT_SAMPLES = SERVER_ROOT.parent / "samples"


def file_digest(path: Path, bits: int) -> TinyHash:
    return TinyHash(path.read_bytes(), bits)


def print_digest(path: Path, bits: int) -> None:
    h = file_digest(path, bits)
    print(f"{h.bindigest():>8}  0x{h.hexdigest():<2}  {path}")


def cmd_hash(args: argparse.Namespace) -> None:
    for path in args.files:
        print_digest(path, args.bits)


def cmd_avalanche(args: argparse.Namespace) -> None:
    print(f"Trials: {args.trials}, one random byte changed per trial")
    print(f"{'Bits':>4} | {'Mean changed':>12} | {f'Trials >= {THRESHOLD:.0%}':>14}")
    print("-" * 37)
    for r in avalanche(args.trials, args.seed):
        print(f"{r.bits:>4} | {r.mean_changed:>12.2%} | {r.share_over_threshold:>14.2%}")


def cmd_collide(args: argparse.Namespace) -> None:
    result = collide_files(args.original, args.modified, args.output, args.bits)
    print(f"Nonce: {result.nonce.decode()}, tries: {result.tries}")
    for path in (args.original, args.modified, args.output):
        print_digest(path, args.bits)


def cmd_samples(args: argparse.Namespace) -> None:
    pairs = generate(args.dir)
    collided = args.dir / "collided"
    collided.mkdir(exist_ok=True)

    print(f"{'File':<10} | {'Original':>8} | {'Modified':>8} | {'Collided':>8} | {'Tries':>5}")
    print("-" * 52)
    for original, modified in pairs:
        output = collided / original.name
        result = collide_files(original, modified, output, args.bits)
        digests = [file_digest(p, args.bits).bindigest() for p in (original, modified, output)]
        print(f"{original.name:<10} | {digests[0]:>8} | {digests[1]:>8} | {digests[2]:>8} | {result.tries:>5}")


def cmd_sign(args: argparse.Namespace) -> None:
    key = load_private_key(args.key) if args.key else load_private_key()
    h = file_digest(args.file, args.bits)
    signature = sign_digest(h.intdigest(), key)
    print(f"Digest:    {h.bindigest()} (0x{h.hexdigest()})")
    print(f"Signature: {signature:x}")
    if args.output:
        args.output.write_text(f"{signature:x}\n")


def cmd_verify(args: argparse.Namespace) -> None:
    key = load_public_key(args.key) if args.key else load_public_key()
    signature = int(args.signature.read_text().strip(), 16)
    h = file_digest(args.file, args.bits)
    valid = verify_digest(h.intdigest(), signature, key)
    print(f"Digest: {h.bindigest()} (0x{h.hexdigest()})")
    print("Signature is VALID" if valid else "Signature is INVALID")
    if not valid:
        sys.exit(1)


def main() -> None:
    parser = argparse.ArgumentParser(prog="cli.py", description="TinyHash: 2/4/8-bit hash function lab")
    sub = parser.add_subparsers(dest="command", required=True)

    def add_bits(p: argparse.ArgumentParser) -> None:
        p.add_argument("-b", "--bits", type=int, choices=SUPPORTED_BITS, default=8, help="digest size")

    p = sub.add_parser("hash", help="compute digests of files")
    p.add_argument("files", nargs="+", type=Path)
    add_bits(p)
    p.set_defaults(func=cmd_hash)

    p = sub.add_parser("avalanche", help="check how many digest bits change on a one-byte change")
    p.add_argument("-n", "--trials", type=int, default=300)
    p.add_argument("--seed", type=int)
    p.set_defaults(func=cmd_avalanche)

    p = sub.add_parser("collide", help="adjust MODIFIED so its digest equals ORIGINAL's")
    p.add_argument("original", type=Path)
    p.add_argument("modified", type=Path)
    p.add_argument("-o", "--output", type=Path, required=True)
    add_bits(p)
    p.set_defaults(func=cmd_collide)

    p = sub.add_parser("samples", help="generate sample documents and collide them")
    p.add_argument("-d", "--dir", type=Path, default=DEFAULT_SAMPLES)
    add_bits(p)
    p.set_defaults(func=cmd_samples)

    p = sub.add_parser("sign", help="sign a file digest with RSA")
    p.add_argument("file", type=Path)
    p.add_argument("-k", "--key", type=Path, help="private key PEM (default: server/private_key.pem)")
    p.add_argument("-o", "--output", type=Path, help="write signature (hex) to a file")
    add_bits(p)
    p.set_defaults(func=cmd_sign)

    p = sub.add_parser("verify", help="verify an RSA signature of a file digest")
    p.add_argument("file", type=Path)
    p.add_argument("signature", type=Path, help="file with the signature in hex")
    p.add_argument("-k", "--key", type=Path, help="public key PEM (default: server/public_key.pem)")
    add_bits(p)
    p.set_defaults(func=cmd_verify)

    args = parser.parse_args()
    try:
        args.func(args)
    except (ValueError, FileNotFoundError, RuntimeError) as error:
        parser.exit(2, f"error: {error}\n")


if __name__ == "__main__":
    main()
```

== Скрипт генерації пари ключів RSA (bin/generate_keys.py) <srv-genkeys>
```python
from pathlib import Path
import sys

SERVER_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SERVER_ROOT / "src"))

from lab3_server.keys import generate_key_pair


if __name__ == "__main__":
    private_key_path = SERVER_ROOT / "private_key.pem"
    public_key_path = SERVER_ROOT / "public_key.pem"
    _, public_key_pem = generate_key_pair(private_key_path, public_key_path)
    print(public_key_pem.decode("ascii"))
```

== Точка входу сервера (bin/main.py) <srv-main>
```python
from pathlib import Path
import sys

SERVER_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SERVER_ROOT / "src"))

from lab3_server.app import app

__all__ = ["app"]
```

= Програмний код клієнтської частини <app-client>
// dstu-ignore-next-line: heading-orphan
== Запити до серверного API (lib/api.ts) <cl-api>
```typescript
export const API_URL = "http://localhost:8000";

export type Bits = 2 | 4 | 8;

export type DigestResult = {
  name: string;
  size: number;
  bits: Bits;
  digest: number;
  binary: string;
  hex: string;
};

export type SignResult = DigestResult & { signature: string };
export type VerifyResult = DigestResult & { valid: boolean };

async function post<T>(path: string, fields: Record<string, string | Blob>): Promise<T> {
  const body = new FormData();
  for (const [key, value] of Object.entries(fields)) {
    body.append(key, value);
  }

  let response: Response;
  try {
    response = await fetch(`${API_URL}${path}`, { method: "POST", body });
  } catch {
    throw new Error("The server is unreachable. Is it running on port 8000?");
  }

  if (!response.ok) {
    const data: unknown = await response.json().catch(() => null);
    const detail =
      typeof data === "object" && data !== null && "detail" in data && typeof data.detail === "string"
        ? data.detail
        : `Request failed (${response.status}).`;
    throw new Error(detail);
  }
  return (await response.json()) as T;
}

export function getDigest(file: File, bits: Bits) {
  return post<DigestResult>("/api/digest", { file, bits: String(bits) });
}

export function signFile(file: File, bits: Bits) {
  return post<SignResult>("/api/sign", { file, bits: String(bits) });
}

export function verifyFile(file: File, signature: string, bits: Bits) {
  return post<VerifyResult>("/api/verify", { file, signature, bits: String(bits) });
}
```

// dstu-ignore-next-line: heading-orphan
== Головна сторінка застосунку (pages/MainPage.tsx) <cl-main>
```tsx
import { Box, Paper, Stack, Tab, Tabs, Typography } from "@mui/material";
import { useState } from "react";
import BitsSelect from "@/components/BitsSelect";
import DigestPanel from "@/components/DigestPanel";
import SignaturePanel from "@/components/SignaturePanel";
import type { Bits } from "@/lib/api";

export default function MainPage() {
  const [tab, setTab] = useState(0);
  const [bits, setBits] = useState<Bits>(8);

  return (
    <Box sx={{ minHeight: "100vh", display: "flex", justifyContent: "center", p: 2 }}>
      <Paper elevation={3} sx={{ p: 3, width: "100%", maxWidth: 720, alignSelf: "flex-start", mt: 6 }}>
        <Stack spacing={2}>
          <Typography variant="h4" sx={{ fontWeight: 800 }}>
            TinyHash
          </Typography>
          <BitsSelect value={bits} onChange={setBits} />
          <Tabs value={tab} onChange={(_, value: number) => setTab(value)}>
            <Tab label="Digest" />
            <Tab label="RSA signature" />
          </Tabs>
          <Box hidden={tab !== 0}>
            <DigestPanel bits={bits} />
          </Box>
          <Box hidden={tab !== 1}>
            <SignaturePanel bits={bits} />
          </Box>
        </Stack>
      </Paper>
    </Box>
  );
}
```

// dstu-ignore-next-line: heading-orphan
== Компонент обчислення та порівняння дайджестів (components/DigestPanel.tsx) <cl-digest>
```tsx
import { Alert, Button, Stack, TextField } from "@mui/material";
import { useState } from "react";
import DigestCard from "@/components/DigestCard";
import FilePicker from "@/components/FilePicker";
import { getDigest, type Bits, type DigestResult } from "@/lib/api";

type Results = { first: DigestResult; second: DigestResult | null; expected: string };

function normalizeExpected(value: string, bits: Bits): number | null {
  const clean = value.trim().toLowerCase();
  if (!clean) return null;
  const parsed = clean.startsWith("0x") ? parseInt(clean.slice(2), 16) : parseInt(clean, 2);
  if (Number.isNaN(parsed) || parsed >= 2 ** bits) return Number.NaN;
  return parsed;
}

export default function DigestPanel({ bits }: { bits: Bits }) {
  const [first, setFirst] = useState<File | null>(null);
  const [second, setSecond] = useState<File | null>(null);
  const [expected, setExpected] = useState("");
  const [results, setResults] = useState<Results | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function compute() {
    if (!first) return;
    setLoading(true);
    setError(null);
    try {
      const [a, b] = await Promise.all([getDigest(first, bits), second ? getDigest(second, bits) : null]);
      setResults({ first: a, second: b, expected });
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
      setResults(null);
    } finally {
      setLoading(false);
    }
  }

  const expectedValue = results ? normalizeExpected(results.expected, results.first.bits) : null;

  return (
    <Stack spacing={2}>
      <FilePicker label="File" file={first} onChange={setFirst} />
      <FilePicker label="Compare with" file={second} onChange={setSecond} />
      <TextField
        size="small"
        label="Expected digest (optional)"
        placeholder="binary, e.g. 00011011, or hex, e.g. 0x1b"
        value={expected}
        onChange={(event) => setExpected(event.target.value)}
      />
      <Button variant="contained" disabled={!first || loading} onClick={compute}>
        Compute digest
      </Button>

      {error && <Alert severity="error">{error}</Alert>}

      {results && (
        <>
          <Stack direction={{ xs: "column", sm: "row" }} spacing={2}>
            <DigestCard title="File" result={results.first} />
            {results.second && <DigestCard title="Compare with" result={results.second} />}
          </Stack>
          {results.second &&
            (results.first.digest === results.second.digest ? (
              <Alert severity="success">Digests match.</Alert>
            ) : (
              <Alert severity="warning">Digests differ.</Alert>
            ))}
          {expectedValue !== null &&
            (Number.isNaN(expectedValue) ? (
              <Alert severity="error">Expected digest is not a valid {results.first.bits}-bit value.</Alert>
            ) : expectedValue === results.first.digest ? (
              <Alert severity="success">Digest matches the expected value: integrity confirmed.</Alert>
            ) : (
              <Alert severity="error">Digest does not match the expected value: integrity violated.</Alert>
            ))}
        </>
      )}
    </Stack>
  );
}
```

// dstu-ignore-next-line: heading-orphan
== Компонент підпису та перевірки підпису (components/SignaturePanel.tsx) <cl-signature>
```tsx
import { Alert, Button, Divider, Stack, TextField, Typography } from "@mui/material";
import { useState } from "react";
import DigestCard from "@/components/DigestCard";
import FilePicker from "@/components/FilePicker";
import { signFile, verifyFile, type Bits, type SignResult, type VerifyResult } from "@/lib/api";

function errorMessage(e: unknown) {
  return e instanceof Error ? e.message : String(e);
}

export default function SignaturePanel({ bits }: { bits: Bits }) {
  const [signTarget, setSignTarget] = useState<File | null>(null);
  const [signed, setSigned] = useState<SignResult | null>(null);
  const [signError, setSignError] = useState<string | null>(null);

  const [verifyTarget, setVerifyTarget] = useState<File | null>(null);
  const [signature, setSignature] = useState("");
  const [verified, setVerified] = useState<VerifyResult | null>(null);
  const [verifyError, setVerifyError] = useState<string | null>(null);

  async function sign() {
    if (!signTarget) return;
    setSignError(null);
    try {
      const result = await signFile(signTarget, bits);
      setSigned(result);
      setSignature(result.signature);
    } catch (e) {
      setSigned(null);
      setSignError(errorMessage(e));
    }
  }

  async function verify() {
    if (!verifyTarget || !signature.trim()) return;
    setVerifyError(null);
    try {
      setVerified(await verifyFile(verifyTarget, signature, bits));
    } catch (e) {
      setVerified(null);
      setVerifyError(errorMessage(e));
    }
  }

  return (
    <Stack spacing={2}>
      <Typography variant="h6">Sign</Typography>
      <FilePicker label="File" file={signTarget} onChange={setSignTarget} />
      <Button variant="contained" disabled={!signTarget} onClick={sign}>
        Sign digest
      </Button>
      {signError && <Alert severity="error">{signError}</Alert>}
      {signed && <DigestCard title="Signed digest" result={signed} />}

      <Divider />

      <Typography variant="h6">Verify</Typography>
      <FilePicker label="File" file={verifyTarget} onChange={setVerifyTarget} />
      <TextField
        label="Signature (hex)"
        multiline
        minRows={3}
        value={signature}
        onChange={(event) => setSignature(event.target.value)}
        slotProps={{ htmlInput: { style: { fontFamily: "monospace", wordBreak: "break-all" } } }}
      />
      <Button variant="contained" disabled={!verifyTarget || !signature.trim()} onClick={verify}>
        Verify signature
      </Button>
      {verifyError && <Alert severity="error">{verifyError}</Alert>}
      {verified && (
        <>
          <DigestCard title="Verified digest" result={verified} />
          {verified.valid ? (
            <Alert severity="success">Signature is valid.</Alert>
          ) : (
            <Alert severity="error">Signature is invalid.</Alert>
          )}
        </>
      )}
    </Stack>
  );
}
```

// dstu-ignore-next-line: heading-orphan
== Компонент картки дайджесту (components/DigestCard.tsx) <cl-card>
```tsx
import { Paper, Stack, Typography } from "@mui/material";
import type { DigestResult } from "@/lib/api";

export default function DigestCard({ title, result }: { title: string; result: DigestResult }) {
  return (
    <Paper variant="outlined" sx={{ p: 2, flex: 1, minWidth: 0 }}>
      <Stack spacing={0.5}>
        <Typography variant="overline" color="text.secondary">
          {title}
        </Typography>
        <Typography variant="body2" noWrap>
          {result.name} · {result.size} bytes
        </Typography>
        <Typography variant="h4" sx={{ fontFamily: "monospace", letterSpacing: 4 }}>
          {result.binary}
        </Typography>
        <Typography variant="body2" color="text.secondary" sx={{ fontFamily: "monospace" }}>
          0x{result.hex} · {result.digest} · {result.bits} bits
        </Typography>
      </Stack>
    </Paper>
  );
}
```

== Компонент вибору файла (components/FilePicker.tsx) <cl-file>
```tsx
import UploadFileIcon from "@mui/icons-material/UploadFile";
import { Button, Stack, Typography } from "@mui/material";

type Props = {
  label: string;
  file: File | null;
  onChange: (file: File | null) => void;
};

export default function FilePicker({ label, file, onChange }: Props) {
  return (
    <Stack direction="row" spacing={2} sx={{ alignItems: "center" }}>
      <Button variant="outlined" component="label" startIcon={<UploadFileIcon />} sx={{ flexShrink: 0 }}>
        {label}
        <input
          hidden
          type="file"
          onChange={(event) => {
            onChange(event.target.files?.[0] ?? null);
            event.target.value = "";
          }}
        />
      </Button>
      <Typography variant="body2" color="text.secondary" noWrap>
        {file ? `${file.name} (${file.size} bytes)` : "No file selected"}
      </Typography>
    </Stack>
  );
}
```

// dstu-ignore-next-line: heading-orphan
== Компонент вибору довжини дайджесту (components/BitsSelect.tsx) <cl-bits>
```tsx
import { Stack, ToggleButton, ToggleButtonGroup, Typography } from "@mui/material";
import type { Bits } from "@/lib/api";

type Props = {
  value: Bits;
  onChange: (bits: Bits) => void;
};

export default function BitsSelect({ value, onChange }: Props) {
  return (
    <Stack direction="row" spacing={2} sx={{ alignItems: "center" }}>
      <Typography variant="body2">Digest size</Typography>
      <ToggleButtonGroup
        size="small"
        exclusive
        value={value}
        onChange={(_, bits: Bits | null) => bits && onChange(bits)}
      >
        {([2, 4, 8] as const).map((bits) => (
          <ToggleButton key={bits} value={bits}>
            {bits} bits
          </ToggleButton>
        ))}
      </ToggleButtonGroup>
    </Stack>
  );
}
```

== Кореневий компонент (App.tsx) <cl-app>
```tsx
import { CssBaseline } from "@mui/material";
import MainPage from "@/pages/MainPage";

export default function App() {
  return (
    <>
      <CssBaseline />
      <MainPage />
    </>
  );
}
```

