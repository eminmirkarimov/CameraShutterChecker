# Полная инструкция: как разместить Camera Shutter Checker на GitHub и сделать EXE доступным для скачивания

Эта инструкция рассчитана на публикацию проекта под вашим GitHub-аккаунтом. Главная цель — чтобы посетитель открыл страницу проекта, нажал **Releases**, скачал `CameraShutterChecker.exe` и запустил программу.

---

## 0. Что в итоге должно получиться

У проекта будет две части:

1. **Repository (репозиторий)** — исходный код, README, инструкции, настройки сборки и история разработки.
2. **Release (релиз)** — готовая программа `CameraShutterChecker.exe`, которую пользователи скачивают без необходимости собирать её самостоятельно.

Страница скачивания после создания репозитория будет выглядеть так:

```text
https://github.com/ВАШ_ЛОГИН/CameraShutterChecker/releases/latest
```

Прямая ссылка на EXE:

```text
https://github.com/ВАШ_ЛОГИН/CameraShutterChecker/releases/latest/download/CameraShutterChecker.exe
```

Вместо `ВАШ_ЛОГИН` будет ваш username на GitHub.

---

## 1. Подготовьте проект на компьютере

1. Скачайте архив проекта, который приложен к этой инструкции.
2. Распакуйте его, например, в `D:\Projects\CameraShutterChecker`.
3. Откройте эту папку в Проводнике Windows.
4. Убедитесь, что в корне находятся файлы:

```text
CameraShutterChecker/
│
├── CameraShutterCheck.ps1
├── CameraShutterCheck.bat
├── BUILD_EXE.bat
├── Build-EXE.ps1
│
├── README.md
├── README_RU.md
├── GITHUB_SETUP_RU.md
├── CHANGELOG.md
├── RELEASE_NOTES_TEMPLATE.md
├── LICENSE_NOTICE.txt
├── .gitignore
│
└── .github/
    └── workflows/
        └── release.yml
```

**Важно:** `README.md`, `CameraShutterCheck.ps1` и папка `.github` должны попасть в репозиторий. Не переименовывайте файлы и не раскладывайте их по разным папкам.

---

## 2. Создайте аккаунт или войдите в GitHub

1. Откройте сайт: <https://github.com/>.
2. Если аккаунт уже есть — нажмите **Sign in** и войдите.
3. Если аккаунта нет — нажмите **Sign up** и зарегистрируйтесь.
4. Подтвердите адрес электронной почты, если GitHub попросит.

Создайте репозиторий именно под тем аккаунтом, который будет владельцем проекта. Не вводите чужой логин в ссылки.

---

## 3. Создайте новый репозиторий

Откройте прямую страницу создания:

**<https://github.com/new>**

Заполните поля так:

| Поле | Что указать |
|---|---|
| Owner | Ваш аккаунт GitHub |
| Repository name | `CameraShutterChecker` |
| Description | `Offline Windows tool to inspect shutter-count metadata in photos and RAW files.` |
| Choose visibility | `Public` |
| Add a README file | **Не отмечать** — свой README уже есть в архиве |
| Add .gitignore | **Не выбирать** — свой `.gitignore` есть в проекте |
| Choose a license | **Не выбирать** — пока действует All Rights Reserved |

После проверки нажмите **Create repository**.

### Почему Public?

Публичный репозиторий позволит людям увидеть страницу проекта, прочитать описание и скачать опубликованный EXE. Исходный код также будет виден. Если вы пока не готовы показывать исходники, создайте Private-репозиторий, но тогда публичная страница скачивания не будет доступна всем.

### Почему не добавлять лицензию GitHub?

В проекте пока указано `All Rights Reserved`. Не выбирайте MIT, GPL или Apache, если вы не хотите разрешать использование, изменение и распространение кода на условиях этих лицензий. Публичный репозиторий сам по себе не превращает проект в open source.

---

## 4. Заполните блок About на странице проекта

После создания репозитория откроется его главная страница. Справа найдите блок **About** и нажмите значок шестерёнки или **Edit**.

Вставьте описание:

```text
Offline Windows tool to inspect shutter-count metadata in photos and RAW files.
```

В поле **Website** пока ничего не указывайте. Когда появится опубликованный релиз, можно добавить прямую ссылку на скачивание.

### Добавьте Topics

В поле Topics по очереди добавьте:

```text
camera
shutter-count
exif
raw
metadata
maker-notes
photography
windows
powershell
```

Topics помогают находить проект по тематике. После заполнения нажмите **Save changes**.

---

## 5. Какие файлы загружать в репозиторий

На главной странице пустого репозитория нажмите:

**Add file → Upload files**

Откройте папку проекта на компьютере и загрузите следующие файлы и папки:

| Что загрузить | Для чего нужно |
|---|---|
| `CameraShutterCheck.ps1` | Основной исходный код приложения и встроенного парсера |
| `CameraShutterCheck.bat` | Запуск программы из исходного кода |
| `BUILD_EXE.bat` | Сборка EXE двойным щелчком на Windows |
| `Build-EXE.ps1` | Настройки сборки и авторские метаданные EXE |
| `README.md` | Главная страница проекта на английском — GitHub показывает её автоматически |
| `README_RU.md` | Полное описание на русском |
| `GITHUB_SETUP_RU.md` | Эта инструкция по публикации и загрузке EXE |
| `CHANGELOG.md` | История версий |
| `RELEASE_NOTES_TEMPLATE.md` | Шаблон текста для релиза |
| `LICENSE_NOTICE.txt` | Авторские права и условия использования |
| `.gitignore` | Исключает временные файлы, логи и папку сборки |
| `.github/workflows/release.yml` | Автоматическая сборка и публикация EXE при отправке тега версии |
| `.github/ISSUE_TEMPLATE/bug_report.md` | Шаблон Issue для запроса поддержки новой камеры / сообщения об ошибке |

### Важный момент про папку `.github`

В Windows папки, начинающиеся с точки, иногда сложнее заметить. Если вы загружаете файлы через Проводник, включите:

**Проводник → Вид → Показать → Скрытые элементы**.

Папку `.github` необходимо сохранить полностью, вместе с двумя вложенными ветками:

```text
.github/
├── ISSUE_TEMPLATE/
│   └── bug_report.md
└── workflows/
    └── release.yml
```

**Если перетаскивание папки `.github` через браузер не сработало, создайте файлы прямо на сайте GitHub:**

1. В репозитории нажмите **Add file → Create new file**.
2. В поле имени файла целиком введите путь:

```text
.github/workflows/release.yml
```

3. На компьютере откройте файл `.github/workflows/release.yml` из архива в Блокноте или VS Code.
4. Скопируйте весь текст и вставьте его в редактор GitHub.
5. Внизу нажмите **Commit changes**.
6. Повторите те же действия для необязательного шаблона обращений:

```text
.github/ISSUE_TEMPLATE/bug_report.md
```

Не размещайте `release.yml` в корне проекта — GitHub Actions не найдёт его там.

### Что НЕ загружать в репозиторий

Не отправляйте:

```text
❌ личные фотографии и RAW-файлы клиентов
❌ папки с приватными тестовыми снимками
❌ личные логи и файлы с приватными путями Windows
❌ временные файлы сборки
❌ папку dist/ с локальными промежуточными результатами
❌ старые и непроверенные EXE
```

Папка `dist/` уже исключена в `.gitignore`. Готовый EXE публикуется отдельно в **Releases → Assets**, а не смешивается с исходниками.

### Завершите загрузку

После перетаскивания файлов вниз страницы найдите **Commit changes**.

В поле заголовка коммита введите:

```text
Initial release: Camera Shutter Checker 2.4.1
```

Описание коммита можно оставить пустым. Вариант `Commit directly to the main branch` подходит для первого размещения. Нажмите **Commit changes**.

После завершения GitHub откроет главную страницу репозитория и автоматически покажет содержимое `README.md`.

> Если браузер не позволяет загрузить вложенную папку `.github`, создайте workflow отдельно способом из раздела 8 ниже или используйте GitHub Desktop / Git.

---

## 6. Как собрать EXE на своём компьютере

Перед публикацией желательно собрать и проверить EXE локально.

1. На Windows откройте папку `CameraShutterChecker`.
2. Дважды нажмите `BUILD_EXE.bat`.
3. При первом запуске сборщик скачает модуль PS2EXE из PowerShell Gallery.
4. Дождитесь сообщения `BUILD SUCCESSFUL`.
5. Откройте папку `dist`.

Готовый файл должен находиться здесь:

```text
CameraShutterChecker\dist\CameraShutterChecker.exe
```

Проверьте его запуск на Windows 10/11 и сделайте тестовую проверку оригинального файла Sony. Не публикуйте EXE, если сборка завершилась с ошибкой или приложение не запускается.

PS2EXE нужен только на этапе создания EXE. Для пользователя, который скачивает готовый файл из GitHub Releases, устанавливать PS2EXE отдельно не нужно. EXE остаётся упакованным PowerShell-приложением и использует системные компоненты Windows PowerShell/.NET.

---

## 7. Как вручную загрузить EXE, чтобы люди могли его скачать

Это самый простой способ, если вы уже собрали и проверили EXE.

1. Откройте главную страницу своего репозитория.
2. Справа найдите **Releases**. Если блок не виден, откройте вкладку/ссылку **Releases** в навигации репозитория.
3. Нажмите **Create a new release**.
4. В поле **Choose a tag** введите:

```text
v2.4.1
```

5. Если GitHub предлагает создать новый тег, выберите создание тега `v2.4.1` от ветки `main`.
6. В поле **Release title** вставьте:

```text
Camera Shutter Checker v2.4.1 — Windows Release
```

7. В поле описания можно вставить текст из файла `RELEASE_NOTES_TEMPLATE.md`.
8. Найдите область **Attach binaries by dropping them here**.
9. Перетащите туда файл:

```text
CameraShutterChecker\dist\CameraShutterChecker.exe
```

10. Убедитесь, что EXE появился в списке прикреплённых файлов.
11. Нажмите **Publish release**.

### Где теперь будет скачивание?

На странице репозитория откройте **Releases** → последний релиз → блок **Assets**. Там пользователи увидят `CameraShutterChecker.exe` и смогут скачать его.

Ссылка на страницу последнего релиза:

```text
https://github.com/ВАШ_ЛОГИН/CameraShutterChecker/releases/latest
```

Прямая ссылка на скачивание EXE:

```text
https://github.com/ВАШ_ЛОГИН/CameraShutterChecker/releases/latest/download/CameraShutterChecker.exe
```

Именно вторую ссылку можно разместить на своём сайте, в портфолио, Telegram-канале или социальных сетях. Ссылка на `latest` будет вести на последний опубликованный релиз.

---

## 8. Автоматическая сборка EXE через GitHub Actions

В архив уже добавлен файл:

```text
.github/workflows/release.yml
```

Он позволяет собирать EXE на сервере GitHub. Вам не нужно вручную собирать файл на своём компьютере для каждого релиза.

### Что делает автоматизация?

Когда вы отправляете тег версии, например `v2.4.1`, GitHub:

1. запускает временный Windows runner;
2. загружает исходники репозитория;
3. устанавливает PS2EXE;
4. собирает `CameraShutterChecker.exe`;
5. создаёт Release с тегом версии;
6. прикрепляет EXE в Assets.

### Как запустить автоматическую публикацию

Автоматический способ использует Git. Если Git ещё не установлен, скачайте Git for Windows:

<https://git-scm.com/download/win>

После установки откройте папку проекта в Проводнике, нажмите правой кнопкой мыши по пустому месту и выберите **Open in Terminal** / **Открыть в терминале**.

Один раз настройте имя и email Git-коммитов (можно использовать имя автора проекта и email, привязанный к GitHub):

```bash
git config --global user.name "Emin Mirkarimov"
git config --global user.email "YOUR_GITHUB_EMAIL"
```

Замените `YOUR_GITHUB_EMAIL` на email, привязанный к GitHub, или на GitHub noreply email из настроек аккаунта.

### Если вы ещё не загружали файлы через браузер

Откройте терминал **в родительской папке**, где хотите хранить проект, и клонируйте созданный репозиторий:

```bash
git clone https://github.com/YOUR_GITHUB_USERNAME/CameraShutterChecker.git
```

Замените `YOUR_GITHUB_USERNAME` на свой GitHub username. Если репозиторий пустой, Git может показать предупреждение, что он пуст, — это нормально.

Теперь скопируйте **содержимое распакованной папки проекта** в новую папку `CameraShutterChecker`, созданную командой `git clone`. Скопируйте и скрытые элементы `.gitignore` и `.github`. Не удаляйте и не заменяйте служебную папку `.git`, которую создал Git при клонировании.

После копирования откройте терминал внутри клонированной папки `CameraShutterChecker` и выполните:

```bash
git add .
git commit -m "Initial release: Camera Shutter Checker 2.4.1"
git push -u origin main
```

### Если файлы уже были загружены через сайт GitHub

Не создавайте новую независимую Git-историю командой `git init` поверх загруженного репозитория: push может быть отклонён из-за несовпадающей истории.

Вместо этого клонируйте существующий репозиторий командой `git clone`, как показано выше. Затем скопируйте обновлённые файлы проекта в полученную папку, не трогая `.git`, и выполните `git add .`, `git commit` и `git push`.

Для публикации следующей версии после внесения изменений:

```bash
git add .
git commit -m "Update Camera Shutter Checker"
git push origin main

git tag v2.4.1
git push origin v2.4.1
```

Тег `v2.4.1` должен быть уникальным. Для следующего релиза используйте новую версию, например `v2.4.2` или `v2.5.0`, и обновите версию приложения/сборщика перед публикацией.

### Разрешения для GitHub Actions

Обычно `GITHUB_TOKEN` создаётся GitHub автоматически. Если публикация Release завершается ошибкой доступа:

1. Откройте репозиторий → **Settings**.
2. В меню слева откройте **Actions → General**.
3. Найдите **Workflow permissions**.
4. Выберите **Read and write permissions**.
5. Нажмите **Save**.

В workflow уже указано `permissions: contents: write`, но настройки организации могут ограничивать права на уровне репозитория.

### Где смотреть результат?

1. В репозитории откройте вкладку **Actions**.
2. Выберите workflow **Build and publish Windows EXE**.
3. Откройте последний запуск и дождитесь зелёной галочки `Success`.
4. Вернитесь в **Releases**.
5. Откройте релиз с нужным тегом.
6. Проверьте, что в **Assets** есть `CameraShutterChecker.exe`.

Если workflow завершился красным крестом, откройте его и посмотрите шаг, на котором возникла ошибка. Не размещайте непроверенный EXE вручную.

---

## 9. Как добавить ссылку на скачивание в README и About

После того как Release уже опубликован, откройте `README.md` и найдите:

```markdown
https://github.com/YOUR_GITHUB_USERNAME/CameraShutterChecker/releases/latest
```

Замените `YOUR_GITHUB_USERNAME` на свой реальный GitHub username. То же сделайте в `README_RU.md`.

Затем откройте `README.md` на GitHub → значок карандаша **Edit this file** → внесите замену → **Commit changes**.

В блоке **About → Edit** можно вставить ссылку в Website:

```text
https://github.com/ВАШ_ЛОГИН/CameraShutterChecker/releases/latest
```

Теперь на главной странице репозитория будет заметна ссылка на скачивание последней версии.

---

## 10. Готовый текст для GitHub Release

Вставьте содержимое файла `RELEASE_NOTES_TEMPLATE.md` в описание релиза. Там уже описаны возможности, Sony-проверка, частичная поддержка Canon и ограничения.

Не пишите, что программа поддерживает все камеры или гарантирует 100% точность: это технически неверно. Укажите, что сейчас практическая проверка выполнена на Sony, Canon CR2/CR3 поддерживается частично и по конкретным моделям.

---

## 11. Как правильно описать поддержку камер

Используйте эти формулировки в описании проекта:

```text
TESTED:
- Sony — practical testing has been performed on a Sony camera.
  Model-specific Sony MakerNotes decoding is implemented for selected bodies.

PARTIAL SUPPORT:
- Canon CR2 / CR3 — model-specific metadata parsing is implemented.
  Some EOS R and selected EOS-1D / EOS-1Ds layouts are handled.
  Many Canon models do not store a lifetime shutter count in image files.

IMPLEMENTED, HARDWARE VALIDATION PENDING:
- Nikon — recognized MakerNotes counter fields.
- Fujifilm — ImageCount field (not always lifetime mechanical count).
- Pentax / Ricoh — selected MakerNotes layout.

NOT YET VERIFIED:
- Panasonic / Lumix
- OM System / Olympus
- Leica
- Other camera brands not listed above
```

Это описание отличает наличие кода от тестирования на настоящей камере.

---

## 12. Финальная проверка перед публикацией

Отметьте пункты перед тем, как дать ссылку другим людям:

- [ ] Репозиторий называется `CameraShutterChecker`.
- [ ] В репозитории есть английский `README.md` и русский `README_RU.md`.
- [ ] В About указано корректное описание и Topics.
- [ ] Загружен `CameraShutterCheck.ps1`.
- [ ] Загружен `CameraShutterCheck.bat`.
- [ ] Загружены `BUILD_EXE.bat` и `Build-EXE.ps1`.
- [ ] Загружена папка `.github/workflows` с `release.yml`.
- [ ] Проверено авторство Emin Mirkarimov.
- [ ] EXE собран и запускается на Windows 10/11.
- [ ] В Release прикреплён `CameraShutterChecker.exe`.
- [ ] README-ссылки `YOUR_GITHUB_USERNAME` заменены на реальный username.
- [ ] Не опубликованы личные фото, RAW-файлы или приватные логи.

---

## Авторство

```text
Project: Camera Shutter Checker
Created and maintained by: Emin Mirkarimov
Copyright (c) 2026 Emin Mirkarimov. All rights reserved.
```

Вопросы и предложения по поддержке новых моделей можно оформлять через **Issues** репозитория. Для запроса новой камеры обязательно указывайте точную модель и расширение оригинального файла.
