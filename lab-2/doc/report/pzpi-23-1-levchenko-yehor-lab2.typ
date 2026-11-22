#import "@local/nure:0.3.0": *
#import style: spacing

#let w = work(
  ..toml("doc.toml"),
)

#set document(..w.document)
#show: style.dstu.with(skip: 1)

#report.title-page(w)

// Автоматична нумерація рядків у лістингах із вказаною мовою.
// Блоки без мови (дерева каталогів тощо) лишаються без номерів.
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
Метою роботи є отримання практичних навичок застосування асиметричних криптографічних алгоритмів для захисту інформації в комп'ютерних мережах, дослідження методики функціонування криптосистеми RSA та програмна реалізація клієнт-серверного застосунку із захищеною передачею автентифікаційних даних через відкритий канал зв'язку з використанням гібридної криптографічної схеми.

== Хід роботи
#v(-spacing)
=== Теоретичні відомості та криптографічні механізми
В основу криптографічної системи з відкритим ключем RSA (Rivest -- Shamir -- Adleman) покладено задачу факторизації цілих чисел -- обчислювальну складність розкладання великого складеного числа на прості співмножники, яка належить до класу обчислювально-односпрямованих завдань @nure_method.

У криптосистемі RSA кожен учасник інформаційного обміну генерує пару взаємопов'язаних ключів: відкритий (public key), який публікується для загального доступу, та закритий (private key), що зберігається в таємниці.

Генерація ключів в алгоритмі RSA здійснюється за таким математичним алгоритмом:
- обираються два випадкових великих простих числа $P$ та $Q$ заданого розміру (наприклад, по 1024 біти для формування 2048-бітного модуля);
- обчислюється їхній добуток $N = P dot Q$, що називається модулем системи;
- обчислюється значення функції Ейлера від модуля: $phi(N) = (P - 1)(Q - 1)$;
- обирається ціле число $E$ ($1 < E < phi(N)$), взаємно просте зі значенням $phi(N)$, де загальноприйнятим галузевим стандартом є використання простого числа Ферма $E = 65537$ ($2^16 + 1$), яке має малу вагу Геммінга у двійковому поданні (лише два одиничні біти), що суттєво оптимізує швидкість операцій перевірки підпису та шифрування;
- обчислюється число $D$, мультиплікативно обернене до числа $E$ за модулем $phi(N)$, тобто таке, що задовольняє співвідношенню $D dot E equiv 1 (mod phi(N))$ (обчислення виконується за допомогою розширеного алгоритму Евкліда).

Пара $P_("pub") = (E, N)$ формує відкритий ключ RSA, а пара $S_("priv") = (D, N)$ є секретним (закритим) ключем. Процедури шифрування та розшифрування блоку повідомлення $M$ ($0 <= M < N$) визначаються співвідношеннями:
$ C equiv M^E (mod N), $ <rsa-enc>
$ M equiv C^D (mod N). $ <rsa-dec>

Хоча класична модель RSA дозволяє безпосередньо шифрувати блоки даних за формулою @rsa-enc, у реальних мережевих протоколах пряме асиметричне шифрування корисного навантаження не застосовується з таких причин:
- низька обчислювальна швидкодія: модульне піднесення до степеня над 2048-бітними числами вимагає на кілька порядків більше процесорного часу порівняно із симетричними перетвореннями;
- обмеження на розмір повідомлення: розмір відкритого тексту не може перевищувати довжину модуля $N$;
- загроза алгебраїчних атак у разі детермінованого шифрування без застосування випадкового вирівнювання (padding).

Тому сучасні захищені протоколи будуються за гібридною архітектурою, де асиметричні механізми забезпечують автентифікацію сторін та узгодження спільних ключів, а безпосередній обмін корисними даними захищається високошвидкісними симетричними алгоритмами. У даній роботі реалізовано саме таку гібридну схему із застосуванням сучасних криптографічних примітивів @stallings_crypto:
- протокол ECDHE (Elliptic-curve Diffie--Hellman Ephemeral): забезпечує динамічне узгодження сесійного секрету на основі стандартної еліптичної кривої SECP256R1 (P-256). Одноразові (ефемерні) пари ключів генеруються для кожного сеансу наново, що гарантує пряму таємність (Forward Secrecy) -- неможливість розшифрування записаного трафіку навіть у разі майбутньої компрометації довготривалих ключів сервера;
- схема цифрового підпису RSA-PSS (Probabilistic Signature Scheme) за стандартом PKCS \#1 v2.2 @rfc8017: використовує довготривалий закритий ключ RSA-2048 сервера для накладання цифрового підпису на обмін відкритими параметрами ECDH. Додавання 32-байтової випадкової солі (salt) та функції генерації маски MGF1 на основі SHA-256 унеможливлює підміну ключів зловмисником та надійно захищає від атаки «людина посередині» (Man-in-the-Middle);
- функція виведення ключів HKDF (HMAC-based Extract-and-Expand Key Derivation Function) @rfc5869: трансформує спільний секрет еліптичної кривої на рівномірний псевдовипадковий 256-бітний ключ симетричного шифрування;
- симетричний блоковий шифр AES-256 у режимі лічильника Галуа (AES-GCM) @nist_gcm: забезпечує автентифіковане шифрування з приєднаними даними (AEAD). Кожна операція шифрування використовує унікальний 12-байтовий вектор ініціалізації (IV) та формує 16-байтовий тег автентифікації, що унеможливлює несанкціоновану модифікацію шифротексту;
- стандарти серіалізації: використання форматів PEM, PKCS \#8 (для приватного ключа сервера), SPKI (для відкритого ключа RSA) та специфікації ANSI X9.62 (для нестиснутих точок еліптичної кривої розміром 65 байтів).

=== Принцип роботи та протокол захищеної взаємодії
Сервер і клієнт здійснюють інформаційний обмін через відкритий незахищений канал зв'язку (протокол HTTP). Процес захищеної передачі автентифікаційних даних складається з кількох послідовних етапів:
+ попередня конфігурація: сервер генерує статичну пару ключів RSA-2048. Закритий ключ зберігається локально на сервері у захищеному файлі, а відкритий ключ серіалізується у форматі PEM (SPKI) і вбудовується у клієнтський застосунок;
+ фаза рукостискання (Handshake):
  + клієнт генерує власну ефемерну пару ключів ECDH (P-256), серіалізує відкритий ключ у 65-байтову нестиснуту точку (X9.62), кодує його за допомогою Base64 та надсилає POST-запитом на ендпоінт `/api/handshake`;
  + сервер перевіряє валідність отриманого відкритого ключа, генерує власну ефемерну пару ключів ECDH (P-256) та обчислює спільний секрет еліптичної кривої;
  + за допомогою алгоритму HKDF(SHA-256) сервер виводить із секрету 256-бітний сесійний ключ AES;
  + для підтвердження своєї автентичності сервер конкатенує байти відкритого ключа сервера та відкритого ключа клієнта, підписує отриманий масив статичним закритим ключем RSA за схемою RSA-PSS із хеш-функцією SHA-256 і довжиною солі 32 байти;
  + сервер створює криптографічно стійкий ідентифікатор сесії, записує сесійний ключ у внутрішній словник активних сесій та встановлює cookie `sid` з атрибутом `HttpOnly`, після чого повертає клієнту відкритий ключ сервера та цифровий підпис;
  + клієнт отримує відповідь і виконує верифікацію підпису RSA-PSS за допомогою заздалегідь відомого статичного відкритого ключа RSA сервера;
  + у разі успішної верифікації клієнт обчислює спільний секрет на базі свого закритого ключа ECDH та відкритого ключа сервера, після чого за допомогою алгоритму HKDF(SHA-256) формує ідентичний сесійний ключ AES-256-GCM у вигляді неекспортованого об'єкта `CryptoKey`;
+ фаза захищеної автентифікації (Login):
  + користувач вводить облікові дані (логін та пароль) у веб-інтерфейсі;
  + клієнт серіалізує дані у формат JSON, генерує унікальний випадковий 12-байтовий вектор ініціалізації (IV) та шифрує JSON-рядок ключем AES-256-GCM;
  + шифротекст та вектор ініціалізації кодуються у Base64 і відправляються на ендпоінт `/api/login` разом із сесійним cookie;
  + сервер за значенням cookie ідентифікує сесію, витягує збережений сесійний ключ AES, розшифровує повідомлення та перевіряє цілісність за тегом автентифікації;
  + після перевірки облікових даних сервер зчитує захищений вміст файлу корисного навантаження (`payload.txt`), шифрує його за допомогою того самого сесійного ключа AES-256-GCM із новим унікальним 12-байтовим IV і повертає зашифровану відповідь;
  + клієнт дешифрує відповідь власним примірником сесійного ключа AES та безпечно відображає отримані дані в інтерфейсі користувача.

=== Архітектура програмного забезпечення
Застосунок спроєктовано за класичною клієнт-серверною архітектурою з чітким розділенням обов'язків та використанням різних мов програмування:
- серверна частина (Backend): реалізована мовою Python з використанням високопродуктивного асинхронного фреймворку FastAPI, ASGI-сервера Uvicorn, криптографічної бібліотеки `cryptography` та бібліотеки валідації `pydantic`;
- клієнтська частина (Frontend): розроблена мовою TypeScript з використанням швидкого середовища виконання Bun, компонентної бібліотеки React, бібліотеки інтерфейсів Material UI (MUI) та вбудованого апаратного браузерного API Web Cryptography (`window.crypto.subtle`).

Структура каталогів розробленого проєкту:

```txt
.
├── client/
│   ├── README.md                      // Інструкція запуску клієнта
│   └── src/
│       ├── App.tsx                    // Кореневий компонент React
│       ├── components/
│       │   ├── Output.tsx             // Блок виведення результату
│       │   └── SignIn.tsx             // Форма автентифікації
│       ├── context/
│       │   └── HandshakeContext.tsx   // Провайдер сесійного ключа
│       ├── lib/
│       │   └── crypto.ts              // Криптографічні операції Web Crypto
│       ├── pages/
│       │   └── MainPage.tsx           // Головна сторінка застосунку
│       └── secrets/
│           └── public_key.pem         // Статичний відкритий ключ сервера
├── doc/
│   ├── report/                        // Звіт за ДСТУ (Typst)
│   ├── Лб№2 RSA.docx
│   └── Лб№2 RSA.pdf
├── README.md                          // Загальний опис роботи
└── server/
    ├── bin/
    │   ├── generate_keys.py           // Скрипт генерації ключів RSA
    │   └── main.py                    // Точка входу сервера FastAPI
    ├── data/
    │   └── payload.txt                // Захищені корисні дані
    ├── pyproject.toml                 // Залежності серверного пакета
    ├── README.md                      // Інструкція запуску сервера
    └── src/
        └── lab2_server/
            ├── __init__.py
            ├── app.py                 // Маршрути API та серверне шифрування
            └── keys.py                // Модуль генерації та завантаження RSA
```

Взаємодія між клієнтом і сервером організована через два кінцеві пункти REST API @fastapi_docs, специфікацію яких наведено у @endpoints-table[таблиці]:

#tab(
  caption: [Специфікація API ендпоінтів сервера],
  columns: (1fr, 2.5fr, 4.5fr),
  header: ([Метод], [Шлях], [Призначення]),
  label: <endpoints-table>,
  [POST],
  [/api/handshake],
  [Службовий ендпоінт для автентифікованого узгодження спільного симетричного ключа AES],
  [POST],
  [/api/login],
  [Приймання зашифрованих облікових даних і повернення зашифрованої корисного навантаження],
)

=== Реалізація та функціонування серверної частини
Серверна частина відповідає за керування довготривалими та сесійними ключами, перевірку вхідних параметрів та авторизацію користувачів.

Генерація статичної пари ключів RSA-2048 виконується утилітою `bin/generate_keys.py` за допомогою функції `generate_key_pair()` з модуля `lab2_server/keys.py`. Функція перевіряє відсутність попередньо створених файлів ключів, після чого генерує пару RSA з довжиною ключа 2048 бітів та публічною експонентою $e = 65537$. Закритий ключ зберігається у форматі PKCS \#8 без парольного захисту, а відкритий -- у форматі SPKI PEM.

Модуль `lab2_server/app.py` визначає логіку обробки запитів:
- при запуску сервера менеджер контексту життєвого циклу `lifespan` зчитує закритий ключ RSA з файлу `private_key.pem`, перевіряє його коректність (розмір 2048 бітів та експоненту 65537) та ініціалізує словник активних сесій `sessions`;
- обробник `/api/handshake` приймає публічну точку клієнта в кодуванні Base64, десеріалізує її як точку еліптичної кривої SECP256R1, генерує серверний ключ ECDH, здійснює операцію `exchange` для отримання спільного секрету та виводить 256-бітний ключ AES за допомогою `HKDF(SHA256)`. Далі формується цифровий підпис `private_key.sign()` за схемою RSA-PSS над об'єднаними відкритими ключами сторін. Сесійний ідентифікатор зберігається у захищеному cookie `sid`;
- обробник `/api/login` отримує шифротекст та вектор ініціалізації IV, перевіряє наявність активного сесійного ключа у cookie `sid`, дешифрує повідомлення за допомогою `AESGCM(aes_key).decrypt()`, розбирає JSON та зіставляє облікові дані з еталонними (`rimworld` / `awolnation`). У разі збігу зчитується файл `payload.txt`, шифрується алгоритмом AES-256-GCM із новим випадковим IV і повертається клієнту у форматі Base64.

Повний програмний код серверних модулів наведено у @app-server[додатку].

=== Реалізація та функціонування клієнтської частини
Клієнтський застосунок забезпечує повний цикл криптографічних перетворень на стороні браузера за допомогою нативного Web Cryptography API @web_crypto:
- модуль `src/lib/crypto.ts` інкапсулює операції генерації ключів ECDH (P-256) через `crypto.subtle.generateKey`, імпортування відкритого ключа RSA за стандартом SPKI через `crypto.subtle.importKey`, верифікацію підпису RSA-PSS з параметром `saltLength: 32` через `crypto.subtle.verify`, обчислення спільного бітового секрету через `crypto.subtle.deriveBits` та генерацію неекспортованого ключа AES-GCM через `crypto.subtle.deriveKey`;
- компонент `src/context/HandshakeContext.tsx` забезпечує централізоване керування станом захищеного з'єднання. Під час монтування компонента за допомогою хука `useEffect` виконується одноразовий запит до сервера для узгодження сесійного ключа. Отриманий `CryptoKey` зберігається в пам'яті браузера і надається через контекст дочірнім компонентам без можливості його прямого витоку;
- компонент `src/components/SignIn.tsx` надає інтерфейс введення імені користувача та пароля. При натисканні кнопки входу формується рядок JSON, генерується 12-байтовий вектор ініціалізації через `crypto.getRandomValues()`, корисне навантаження шифрується методом `crypto.subtle.encrypt(AES-GCM)` і надсилається на сервер. Відповідь сервера дешифрується методом `crypto.subtle.decrypt()`;
- компонент `src/components/Output.tsx` відповідає за коректне відображення розшифрованого вмісту захищеного корисного навантаження з використанням спеціалізованого моноширинного блоку `ChatCodeBlock`;
- компонент `src/pages/MainPage.tsx` об'єднує компоненти інтерфейсу в єдиний адаптивний макет сторінки.

Повний програмний код клієнтських компонентів наведено у @app-client[додатку].

=== Результати виконання
Зовнішній вигляд інтерфейсу користувача та результати роботи застосунку представлено на @fig-signin[рисунку], @fig-success[рисунку] та @fig-error[рисунку]:

#figure(
  image("assets/web-view.png", width: 85%),
  caption: [Форма автентифікації клієнтського веб-застосунку],
) <fig-signin>

#figure(
  image("assets/web-view-content.png", width: 95%),
  caption: [Результат успішної автентифікації та відображення розшифрованого корисного навантаження (ASCII-арт)],
) <fig-success>

#figure(
  image("assets/web-view-error.png", width: 85%),
  caption: [Відображення помилки авторизації у разі введення некоректних облікових даних],
) <fig-error>

== Висновки
У результаті виконання лабораторної роботи було:
- досліджено теоретичні засади та математичний апарат асиметричної криптографічної системи RSA, зокрема процедури факторизації, генерації ключів на основі простих чисел, обчислення функції Ейлера та виконання операцій шифрування й розшифрування за модулем $N$;
- проаналізовано переваги та недоліки асиметричних криптосистем і обґрунтовано необхідність застосування гібридного підходу для захисту каналів зв'язку в сучасних розподілених мережевих додатках;
- спроєктовано та реалізовано повноцінний клієнт-серверний застосунок з використанням різних мов програмування: серверної частини на Python (FastAPI, cryptography) та клієнтської частини на TypeScript (React, Bun, Web Crypto API);
- розроблено протокол захищеного обміну даними через відкритий канал зв'язку, який поєднує узгодження сесійних ключів за схемою ECDHE (P-256), автентифікацію сервера за допомогою цифрового підпису RSA-PSS (RSA-2048, SHA-256), виведення ключів за допомогою HKDF(SHA-256) та автентифіковане шифрування трафіку алгоритмом AES-256-GCM;
- створено зручний графічний веб-інтерфейс для введення облікових даних та відображення захищеного корисного навантаження, перевірено стійкість системи до типових загроз та атак типу «людина посередині».

Отримана система забезпечує властивості конфіденційності, цілісності, автентичності та прямої таємності (Forward Secrecy).

== Контрольні запитання
1\. Які криптографічні шифри називають несиметричними?

Симетричність криптографічного шифру визначається організацією ключів шифрування:
- симетричними називають шифри, у яких один і той самий секретний ключ застосовується як для зашифрування відкритого тексту, так і для його розшифрування;
- асиметричними (несиметричними) називають криптографічні алгоритми, що використовують пару математично пов'язаних, проте функціонально розділених ключів: відкритий ключ (public key), доступний для вільного публічного поширення і призначений для шифрування даних або перевірки цифрового підпису, та закритий (таємний) ключ (private key), відомий виключно законному власнику і призначений для розшифрування повідомлень або накладання цифрового підпису. При цьому обчислення закритого ключа на основі відкритого є обчислювально нездійсненною задачею за прийнятний час.

2\. На якій складній задачі засновано алгоритм RSA?

Алгоритм RSA базується на задачі факторизації цілих чисел -- обчислювальній складності розкладання великого складеного числа $N$ на його прості множники $P$ та $Q$. У той час як операція множення двох великих простих чисел виконується поліноміально швидко, зворотна дія знаходження співмножників для модулів довжиною 2048--4096 бітів потребує субполіноміального часу (за допомогою методу решета числового поля) та гігантських обчислювальних ресурсів, що є практично невирішуваним завданням на класичних обчислювальних машинах.

3\. Як генеруються відкритий та секретний ключі?

Генерація ключів в алгоритмі RSA здійснюється за п'ять послідовних етапів:
- за допомогою криптографічно стійкого генератора псевдовипадкових чисел та ймовірнісних тестів простоти (зокрема тесту Міллера -- Рабіна) обираються два великих випадкових простих числа $P$ та $Q$;
- обчислюється відкритий модуль системи $N = P dot Q$, розрядність якого в бітах визначає довжину ключа;
- обчислюється значення функції Ейлера $phi(N) = (P - 1)(Q - 1)$ (або функції Кармайкла $lambda(N) = "НСК"(P - 1, Q - 1)$);
- обирається ціле число $E$ (відкрита експонента), взаємно просте зі значенням $phi(N)$ в інтервалі $1 < E < phi(N)$, де на практиці обирається просте число Ферма $E = 65537$;
- за допомогою розширеного алгоритму Евкліда обчислюється число $D$ (закрита експонента), мультиплікативно обернене до числа $E$ за модулем $phi(N)$: $D dot E equiv 1 (mod phi(N))$.

У результаті пара $(E, N)$ публікується як відкритий ключ, пара $(D, N)$ утворює секретний закритий ключ, а вихідні параметри $P$, $Q$ та $phi(N)$ безповоротно видаляються з оперативної пам'яті.

4\. Як проходить шифрування та розшифрування по алгоритму RSA?

Процедури шифрування та розшифрування за алгоритмом RSA проходять так:
- вхідне відкрите повідомлення попередньо кодується у вигляді цілого числа $M$ ($0 <= M < N$) із обов'язковим додаванням псевдовипадкових байтів за стандартизованими схемами вирівнювання (наприклад, RSA-OAEP) для забезпечення недетермінованості шифротексту;
- шифрування здійснюється за допомогою відкритого ключа адресата $(E, N)$ шляхом піднесення числа $M$ до степеня $E$ за модулем $N$: $C equiv M^E (mod N)$;
- розшифрування здійснюється законним отримувачем за допомогою закритого ключа $(D, N)$ за формулою: $M equiv C^D (mod N)$.

Математична коректність відновлення початкового повідомлення гарантується теоремою Ейлера: оскільки показники $E$ та $D$ пов'язані рівністю $E dot D equiv 1 (mod phi(N))$, тобто $E dot D = 1 + k dot phi(N)$, то $M^(E dot D) = M^(1 + k dot phi(N)) equiv M (mod N)$. На практиці RSA застосовується у складі гібридних схем або для створення цифрових підписів за схемою RSA-PSS.

5\. Які є недоліки у алгоритмів з відкритим ключем?

До ключових недоліків асиметричних криптографічних алгоритмів належать:
- низька швидкодія: виконання операцій модульної арифметики над великими числами вимагає на два-три порядки більше ресурсів порівняно зі швидкими бітовими перетвореннями симетричних блокових шифрів;
- великий розмір ключів: для забезпечення криптостійкості, еквівалентної 128-бітному ключу симетричного шифру AES, алгоритм RSA вимагає ключ довжиною не менше 3072 бітів;
- обмеження максимального розміру блоку даних розміром модуля $N$;
- складність підтвердження автентичності відкритого ключа та вразливість до атак «людина посередині», що викликає необхідність побудови та адміністрування інфраструктури відкритих ключів (PKI) та цифрових сертифікатів;
- потенційна вразливість до квантових комп'ютерів через квантовий алгоритм Шора, що дозволяє знайти факторизацію модуля за поліноміальний час.

6\. Що мається на увазі під поняттям незворотної функції?

Під незворотною (або односторонньою) функцією у криптографії розуміють математичне перетворення $y = f(x)$, яке має такі властивості:
- пряме обчислення значення функції $y = f(x)$ за відомим аргументом $x$ виконується за поліноміальний час і не становить складності;
- зворотна задача знаходження прообразу $x$ за відомим значенням $y$ є обчислювально нездійсненною за прийнятний час із використанням сучасних обчислювальних комплексів.

На практиці розрізняють:
- чисті односторонні функції: лежать в основі криптографічних геш-функцій (наприклад, сімейства SHA-2), де відновлення вхідних даних неможливе за жодних умов;
- односторонні функції з «лазівкою» (секретним входом, trapdoor one-way functions): обернення перетворення є практично нездійсненним без додаткової інформації, проте стає легко обчислюваним за наявності спеціального секретного ключа (лазівки), що є фундаментальним базисом асиметричної криптографії та алгоритму RSA.

#bib(path("bibl.yml"), style: "3008")

#show: style.appendices

= Програмний код серверної частини <app-server>
== Скрипт генерації статичної пари ключів RSA (bin/generate_keys.py) <server-keys-gen>
```python
from pathlib import Path
import sys

SERVER_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SERVER_ROOT / "src"))

from lab2_server.keys import generate_key_pair


if __name__ == "__main__":
    private_key_path = SERVER_ROOT / "private_key.pem"
    public_key_path = SERVER_ROOT / "public_key.pem"
    _, public_key_pem = generate_key_pair(private_key_path, public_key_path)
    print(public_key_pem.decode("ascii"))
```

== Модуль роботи з криптографічними ключами (src/lab2_server/keys.py) <server-keys-mod>
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

== Основний модуль сервера та API (src/lab2_server/app.py) <server-app-mod>
```python
import base64
import binascii
import json
import secrets
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from pathlib import Path

from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec, padding, rsa
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.hkdf import HKDF
from fastapi import FastAPI, HTTPException, Request, Response
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel


PAYLOAD_PATH = Path(__file__).parents[2] / "data" / "payload.txt"
PRIVATE_KEY_PATH = Path(__file__).parents[2] / "private_key.pem"


app = FastAPI(lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://localhost:5173"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class HandshakeRequest(BaseModel):
    clientPub: str


class LoginRequest(BaseModel):
    iv: str
    ciphertext: str


@app.post("/api/handshake")
async def handshake(request: HandshakeRequest, response: Response, http_request: Request) -> dict[str, str]:
    client_public_bytes = decode_base64(request.clientPub)
    if len(client_public_bytes) != 65 or client_public_bytes[0] != 4:
        raise HTTPException(status_code=400, detail="Invalid client public key.")
    try:
        client_public_key = ec.EllipticCurvePublicKey.from_encoded_point(ec.SECP256R1(), client_public_bytes)
    except ValueError as error:
        raise HTTPException(status_code=400, detail="Invalid client public key.") from error

    server_private_key = ec.generate_private_key(ec.SECP256R1())
    server_public_bytes = server_private_key.public_key().public_bytes(
        serialization.Encoding.X962,
        serialization.PublicFormat.UncompressedPoint,
    )
    aes_key = derive_aes_key(server_private_key.exchange(ec.ECDH(), client_public_key))
    signature = http_request.app.state.private_key.sign(
        server_public_bytes + client_public_bytes,
        padding.PSS(mgf=padding.MGF1(hashes.SHA256()), salt_length=32),
        hashes.SHA256(),
    )

    session_id = secrets.token_urlsafe(32)
    http_request.app.state.sessions[session_id] = aes_key
    response.set_cookie(key="sid", value=session_id, httponly=True, samesite="lax", secure=False, path="/")
    return {
        "serverPub": base64.b64encode(server_public_bytes).decode("ascii"),
        "signature": base64.b64encode(signature).decode("ascii"),
    }


@app.post("/api/login")
async def login(request: LoginRequest, http_request: Request) -> dict[str, str]:
    session_id = http_request.cookies.get("sid")
    aes_key = http_request.app.state.sessions.get(session_id or "")
    if aes_key is None:
        raise HTTPException(status_code=401, detail="Handshake required.")

    iv = decode_base64(request.iv)
    ciphertext = decode_base64(request.ciphertext)
    if len(iv) != 12 or len(ciphertext) < 16:
        raise HTTPException(status_code=400, detail="Invalid encrypted request.")

    try:
        payload_bytes = AESGCM(aes_key).decrypt(iv, ciphertext, None)
        payload = json.loads(payload_bytes)
    except (InvalidTag, ValueError, UnicodeDecodeError, json.JSONDecodeError) as error:
        raise HTTPException(status_code=400, detail="Invalid encrypted request.") from error

    if (
        not isinstance(payload, dict)
        or not isinstance(payload.get("login"), str)
        or not isinstance(payload.get("password"), str)
    ):
        raise HTTPException(status_code=400, detail="Invalid encrypted request.")

    if payload["login"] != "rimworld" or payload["password"] != "awolnation":
        raise HTTPException(status_code=401, detail="Invalid login or password.")

    with open(PAYLOAD_PATH, "r", encoding="utf-8") as file:
        content = file.read()

    response_iv = secrets.token_bytes(12)
    response_ciphertext = AESGCM(aes_key).encrypt(
        response_iv,
        content.encode("utf-8"),
        None,
    )
    return {
        "iv": base64.b64encode(response_iv).decode("ascii"),
        "ciphertext": base64.b64encode(response_ciphertext).decode("ascii"),
    }


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    try:
        app.state.private_key = load_private_key()
    except FileNotFoundError as error:
        raise RuntimeError(
            "RSA private key is missing. Run `python bin/generate_keys.py`."
        ) from error
    app.state.sessions = {}
    yield


@app.exception_handler(RequestValidationError)
async def invalid_request_handler(request: Request, error: RequestValidationError) -> JSONResponse:
    return JSONResponse(status_code=400, content={"detail": "Invalid request."})


def decode_base64(value: str) -> bytes:
    try:
        return base64.b64decode(value, validate=True)
    except (binascii.Error, ValueError) as error:
        raise HTTPException(status_code=400, detail="Invalid request.") from error


def derive_aes_key(shared_secret: bytes) -> bytes:
    return HKDF(
        algorithm=hashes.SHA256(),
        length=32,
        salt=bytes(32),
        info=b"lab2-login-v1",
    ).derive(shared_secret)


def load_private_key() -> rsa.RSAPrivateKey:
    key = serialization.load_pem_private_key(PRIVATE_KEY_PATH.read_bytes(), password=None)
    if not isinstance(key, rsa.RSAPrivateKey) or key.key_size != 2048:
        raise RuntimeError("private_key.pem must contain an RSA-2048 private key.")
    if key.public_key().public_numbers().e != 65537:
        raise RuntimeError("private_key.pem must use public exponent 65537.")
    return key
```

= Програмний код клієнтської частини <app-client>
== Модуль криптографічних протоколів (src/lib/crypto.ts) <client-crypto-mod>
```typescript
import serverPublicKeyPem from "@/secrets/public_key.pem" with { type: "text" };

type HandshakeResponse = {
  serverPub: string;
  signature: string;
};

type HandshakeResult = {
  clientKeyPair: CryptoKeyPair;
  clientPublicBytes: Uint8Array<ArrayBuffer>;
  serverPublicBytes: Uint8Array<ArrayBuffer>;
  signature: Uint8Array<ArrayBuffer>;
};

/// Encodes a Uint8Array into a base64-encoded string.
export function encodeBase64(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary);
}

/// Decodes a base64-encoded string into a Uint8Array.
export function decodeBase64(value: string): Uint8Array<ArrayBuffer> {
  const binary = atob(value);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index++) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes;
}

/// Establishes a session key with the server using ECDH and HKDF.
export async function establishSessionKey(): Promise<CryptoKey> {
  const handshake = await requestHandshake();
  await verifyServerSignature(handshake);
  return deriveSessionAesKey(handshake);
}

/// Generates a new ECDH key pair, sends the public key to the server, and 
/// receives the server's public key and signature.
async function requestHandshake(): Promise<HandshakeResult> {
  const clientKeyPair = await crypto.subtle.generateKey(
    { name: "ECDH", namedCurve: "P-256" },
    false,
    ["deriveBits"],
  );
  const clientPublicBytes = new Uint8Array(
    await crypto.subtle.exportKey("raw", clientKeyPair.publicKey),
  );

  const response = await fetch("http://localhost:8000/api/handshake", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    credentials: "include",
    body: JSON.stringify({ clientPub: encodeBase64(clientPublicBytes) }),
  });
  if (!response.ok) {
    throw new Error(`Handshake failed (${response.status}).`);
  }

  const data: unknown = await response.json();
  if (!isHandshakeResponse(data)) {
    throw new Error("The API returned an invalid handshake response.");
  }

  const serverPublicBytes = decodeBase64(data.serverPub);
  const signature = decodeBase64(data.signature);
  if (clientPublicBytes.length !== 65 || serverPublicBytes.length !== 65) {
    throw new Error("The API returned an invalid P-256 public key.");
  }

  return { clientKeyPair, clientPublicBytes, serverPublicBytes, signature };
}

/// Verifies the server's signature on the handshake response using the known
/// RSA public key.
async function verifyServerSignature(handshake: HandshakeResult): Promise<void> {
  const rsaPublicKey = await crypto.subtle.importKey(
    "spki",
    toArrayBuffer(pemToBytes(serverPublicKeyPem)),
    { name: "RSA-PSS", hash: "SHA-256" },
    false,
    ["verify"],
  );
  const signedBytes = new Uint8Array(
    handshake.serverPublicBytes.length + handshake.clientPublicBytes.length,
  );
  signedBytes.set(handshake.serverPublicBytes);
  signedBytes.set(handshake.clientPublicBytes, handshake.serverPublicBytes.length);

  const signatureIsValid = await crypto.subtle.verify(
    { name: "RSA-PSS", saltLength: 32 },
    rsaPublicKey,
    handshake.signature,
    signedBytes,
  );
  if (!signatureIsValid) {
    throw new Error("The server handshake signature is invalid.");
  }
}

/// Derives the AES-GCM session key from the shared secret using HKDF.
async function deriveSessionAesKey(handshake: HandshakeResult): Promise<CryptoKey> {
  const serverPublicKey = await crypto.subtle.importKey(
    "raw",
    handshake.serverPublicBytes,
    { name: "ECDH", namedCurve: "P-256" },
    false,
    [],
  );
  const sharedSecret = await crypto.subtle.deriveBits(
    { name: "ECDH", public: serverPublicKey },
    handshake.clientKeyPair.privateKey,
    256,
  );
  const hkdfKey = await crypto.subtle.importKey(
    "raw",
    sharedSecret,
    "HKDF",
    false,
    ["deriveKey"],
  );
  return crypto.subtle.deriveKey(
    {
      name: "HKDF",
      hash: "SHA-256",
      salt: new Uint8Array(32),
      info: new TextEncoder().encode("lab2-login-v1"),
    },
    hkdfKey,
    { name: "AES-GCM", length: 256 },
    false,
    ["encrypt", "decrypt"],
  );
}

function isHandshakeResponse(value: unknown): value is HandshakeResponse {
  return (
    typeof value === "object" &&
    value !== null &&
    "serverPub" in value &&
    typeof value.serverPub === "string" &&
    "signature" in value &&
    typeof value.signature === "string"
  );
}

/// Converts a Uint8Array into an ArrayBuffer.
function toArrayBuffer(bytes: Uint8Array): ArrayBuffer {
  const buffer = new ArrayBuffer(bytes.length);
  new Uint8Array(buffer).set(bytes);
  return buffer;
}

/// Converts a PEM-encoded public key into a Uint8Array.
function pemToBytes(pem: string): Uint8Array {
  const body = pem
    .replace("-----BEGIN PUBLIC KEY-----", "")
    .replace("-----END PUBLIC KEY-----", "")
    .replace(/\s/g, "");
  return decodeBase64(body);
}
```

== Контекст сеансового рукостискання (src/context/HandshakeContext.tsx) <client-context-mod>
```typescript
import { createContext, useContext, useEffect, useRef, useState, type ReactNode } from "react";
import { establishSessionKey } from "@/lib/crypto";

type HandshakeContextValue = {
  aesKey: CryptoKey | null;
  error: string | null;
  isLoading: boolean;
};

/// A React context that provides the AES session key, any handshake error, and 
/// the loading state.
const HandshakeContext = createContext<HandshakeContextValue | undefined>(undefined);

type Props = {
  children: ReactNode;
};

/// A React context provider that establishes a secure session key with the server 
/// and provides it to its children.
export function HandshakeProvider({ children }: Props) {
  const [aesKey, setAesKey] = useState<CryptoKey | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const handshakeStarted = useRef(false);

  useEffect(() => {
    if (handshakeStarted.current) {
      return;
    }
    handshakeStarted.current = true;

    async function initializeSession() {
      try {
        setAesKey(await establishSessionKey());
      } catch (handshakeError) {
        setError(
          handshakeError instanceof Error
            ? handshakeError.message
            : "Could not complete the handshake.",
        );
      } finally {
        setIsLoading(false);
      }
    }

    void initializeSession();
  }, []);

  return (
    <HandshakeContext.Provider value={{ aesKey, error, isLoading }}>
      {children}
    </HandshakeContext.Provider>
  );
}

export function useHandshake() {
  const context = useContext(HandshakeContext);
  if (context === undefined) {
    throw new Error("useHandshake must be used within a HandshakeProvider.");
  }
  return context;
}
```

== Компонент форми автентифікації (src/components/SignIn.tsx) <client-signin-mod>
```typescript
import { Alert, Box, Button, Paper, Stack, Typography } from "@mui/material";
import TextField from "@mui/material/TextField";
import { useState, type FormEvent } from "react";
import { decodeBase64, encodeBase64 } from "@/lib/crypto";
import { useHandshake } from "@/context/HandshakeContext";

type Props = {
  onSuccess: (content: string) => void;
};

type LoginResponse = {
  iv: string;
  ciphertext: string;
};

function isLoginResponse(value: unknown): value is LoginResponse {
  return (
    typeof value === "object" &&
    value !== null &&
    "iv" in value &&
    typeof value.iv === "string" &&
    "ciphertext" in value &&
    typeof value.ciphertext === "string"
  );
}

export default function SignIn({ onSuccess }: Props) {
  const { aesKey, error: handshakeError, isLoading } = useHandshake();
  const [login, setLogin] = useState("");
  const [password, setPassword] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setIsSubmitting(true);
    setError(null);

    try {
      if (!aesKey) {
        throw new Error("Complete the handshake before signing in.");
      }

      const iv = crypto.getRandomValues(new Uint8Array(12));
      const payload = new TextEncoder().encode(JSON.stringify({ login, password }));
      const ciphertext = await crypto.subtle.encrypt(
        { name: "AES-GCM", iv },
        aesKey,
        payload,
      );
      const response = await fetch("http://localhost:8000/api/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        credentials: "include",
        body: JSON.stringify({
          iv: encodeBase64(iv),
          ciphertext: encodeBase64(new Uint8Array(ciphertext)),
        }),
      });

      if (!response.ok) {
        setError(
          response.status === 401
            ? "Invalid login or password, or the handshake session has expired."
            : `Request failed (${response.status}).`,
        );
        return;
      }

      const data: unknown = await response.json();
      if (!isLoginResponse(data)) {
        throw new Error("The API returned an invalid login response.");
      }

      const responseIv = decodeBase64(data.iv);
      const responseCiphertext = decodeBase64(data.ciphertext);
      if (responseIv.length !== 12) {
        throw new Error("The API returned an invalid response IV.");
      }

      const plaintext = await crypto.subtle.decrypt(
        {
          name: "AES-GCM",
          iv: responseIv,
        },
        aesKey,
        responseCiphertext,
      );
      onSuccess(new TextDecoder().decode(plaintext));
    } catch (submitError) {
      setError(
        submitError instanceof Error
          ? submitError.message
          : "Could not complete secure sign-in.",
      );
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <Paper elevation={4} sx={{ width: "100%", maxWidth: 420, p: 4 }}>
      <Stack component="form" spacing={2} onSubmit={handleSubmit}>
        <Box>
          <Typography variant="h4" sx={{ fontWeight: 800 }}>
            Get data securely :3
          </Typography>
        </Box>

        {handshakeError && (
          <Alert severity="error">
            Secure sign-in could not be initialized. Reload the page to retry.
          </Alert>
        )}
        {error && <Alert severity="error">{error}</Alert>}

        <TextField
          required
          label="Login"
          value={login}
          onChange={event => {
            setError(null);
            setLogin(event.target.value);
          }}
          autoComplete="username"
        />

        <TextField
          required
          label="Password"
          type="password"
          value={password}
          onChange={event => {
            setError(null);
            setPassword(event.target.value);
          }}
          autoComplete="current-password"
        />

        <Button
          type="submit"
          variant="contained"
          disabled={isSubmitting || isLoading || !aesKey}
        >
          {isSubmitting ? "Signing in..." : "Sign in"}
        </Button>
      </Stack>
    </Paper>
  );
}
```

== Компонент відображення навантаження (src/components/Output.tsx) <client-output-mod>
```typescript
import { Box, Paper, Typography } from "@mui/material";
import { ChatCodeBlock } from '@mui/x-chat';

type Props = {
  content: string
  outputVisibility: 'hidden' | 'visible'
}

export default function Output({ content, outputVisibility }: Props) {
  return (
    <Paper elevation={4} sx={{ width: '100%', maxWidth: 1260, p: 4, visibility: outputVisibility }}>
      <Box>
        <ChatCodeBlock language="txt" sx={{ fontWeight: 800 }} >
          {content}
        </ChatCodeBlock>
      </Box>
    </Paper>
  );
}
```

== Головна сторінка застосунку (src/pages/MainPage.tsx) <client-mainpage-mod>
```typescript
import { Box, Stack } from "@mui/material";
import { useState } from "react";
import Output from "@/components/Output";
import SignIn from "@/components/SignIn";

export default function MainPage() {
  const [content, setContent] = useState("");
  const [outputVisibility, setOutputVisibility] = useState<"hidden" | "visible">("hidden");

  function onSuccess(responseContent: string) {
    setContent(responseContent);
    setOutputVisibility("visible");
  }

  return (
    <Box sx={{ minHeight: "70vh", display: "grid", placeItems: "center" }}>
      <Stack spacing={2} sx={{ justifyContent: "center", alignItems: "center" }}>
        <SignIn onSuccess={onSuccess} />
        <Output content={content} outputVisibility={outputVisibility} />
      </Stack>
    </Box>
  );
}
```
