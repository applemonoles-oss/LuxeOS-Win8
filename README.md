# LuxeOS 8

Кастомизируемая операционная система на базе **LuxeOS 8** (ядро — Windows 8.1) с
собственным антивирусом **LuxeMalware** и центром кастомизации **LuxeTweak**.

> LuxeOS 8 — это брендированная сборка поверх официального Windows 8.1.
> Кастомизация делается через **DISM + autounattend.xml** поверх легального
> образа Microsoft (подход подтверждён проектами UnattendedWinstall,
> stschulte/custom-windows-11-install, marcinmajsc/uup-dump-build-and-get-windows-iso).

---

## Состав

| Компонент | Файл | Назначение |
|-----------|------|------------|
| **LuxeMalware** | `tools/LuxeMalware.ps1` | Скан: хэш-сигнатуры + строковые паттерны + эвристика; карантин; real-time через `FileSystemWatcher` (задача планировщика); `install`/`uninstall`/`status`/`test` |
| **LuxeTweak** | `tools/LuxeTweak.ps1` | Обои, цвет акцента (DWM), автоскрытие панели, прозрачность/стекло, пресеты `LuxeDark/Light/Glass/Retro` |
| Базы сигнатур | `tools/signatures/{hashes.db,patterns.db}` | Те же базы, что и в Linux-версии |
| Автоустановка | `iso/autounattend.xml` | Unattended Install: локальный аккаунт `LuxeOS`, пропуск OOBE, русская локаль |
| Первичная настройка | `iso/SetupComplete.cmd`, `iso/postinstall.ps1` | На первом запуске применяет пресет `LuxeGlass` и ставит real-time антивирус |
| Сборка образа | `iso/build-iso.ps1` | DISM-слайсстрим инструментов в `install.wim` + пересборка ISO через ADK |

Инструменты написаны на чистом PowerShell и **работают на LuxeOS 8** (совместимо с
Windows 8/10/11) — проверено прямо в этом окружении: детект и карантин работают.

---

## Быстрый старт (без сборки ISO)

Инструменты можно использовать сразу на любом LuxeOS 8:

```powershell
cd LuxeOS-Win8\tools
.\LuxeMalware.ps1 scan ~\Downloads      # проверить папку
.\LuxeMalware.ps1 test                  # EICAR-тест
.\LuxeMalware.ps1 install               # поставить real-time защиту (от админа)
.\LuxeMalware.ps1 status

.\LuxeTweak.ps1 preset apply LuxeGlass  # применить пресет оформления
.\LuxeTweak.ps1 glass on
.\LuxeTweak.ps1 status
```

---

## Сборка кастомного ISO (для виртуалки)

Требуется **LuxeOS 8 + права админа + Windows ADK** (компонент Deployment Tools).
Саму базу Windows 8.1 ISO нужно получить легально (Microsoft / UUP dump) — скрипт
её не скачивает и не распространяет.

```powershell
# от администратора:
cd LuxeOS-Win8\iso
.\build-iso.ps1 -SourceISO "C:\iso\Win8.1.iso" -WorkDir "C:\work" -OutputISO "C:\LuxeOS.iso"
```

Что делает скрипт:
1. Монтирует исходный ISO и копирует содержимое.
2. Монтирует `sources\install.wim` через DISM.
3. Копирует `tools\*` в `ProgramData\LuxeOS\tools` образа.
4. Кладёт `SetupComplete.cmd` + `postinstall.ps1` в системную папку **`Windows\Setup\Scripts`** (имя папки оставлено как у Windows — иначе Setup не найдёт скрипт).
5. Коммитит образ и копирует `autounattend.xml` в корень.
6. Пересобирает загрузочный ISO через `oscdimg` (ADK).

Результат — `LuxeOS.iso`. Запустите в VirtualBox/VMware/Hyper-V: при первом входе
автоматически применится тема `LuxeGlass` и включится real-time антивирус, в меню
Пуск появятся ярлыки LuxeTweak/LuxeMalware.

---

## Автосборка в GitHub Actions (облако)

Полностью собрать ISO в облаке нельзя «бесплатно», т.к. **UUP dump не
поддерживает Windows 8.1** (только Win10/11). Поэтому базовый ISO
предоставляете вы, а CI делает слайсстрим и пересборку:

1. Создайте репозиторий и добавьте код (папку `LuxeOS-Win8`).
2. В настройках репозитория → Secrets добавьте `WIN81_ISO_URL` —
   прямую ссылку на **легальный** Windows 8.1 ISO (например, скачанный
   вами Enterprise Evaluation или собственный хост).
3. Запустите workflow `Build LuxeOS ISO` (кнопка Run workflow) — либо он
   сработает автоматически при push в `main`.
4. Скачайте артефакт `LuxeOS-iso` (файл `LuxeOS.iso`).

Что делает workflow: ставит Windows ADK (oscdimg), качает базу из секрета,
запускает `build-iso.ps1`, выкладывает готовый ISO.

> Альтернатива для Win10/11: если готовы перейти на Windows 10/11, можно
> заменить шаг загрузки на `marcinmajsc/uup-dump-build-and-get-windows-iso`
> (UUP dump строит ISO сам, без вашего файла).

## Возможности LuxeMalware

- **Сигнатуры (SHA-256)** — `hashes.db`, авто-карантин при совпадении.
- **Паттерны (YARA-lite)** — `patterns.db` (reverse-shell, загрузчики, обфускация).
- **Эвристика** — двойное расширение, reverse-shell, PE без расширения.
- **Карантин** — `quarantine` / `restore` / `list` с метаданными.
- **Real-time** — задача в Планировщике + `FileSystemWatcher` по профилю/Downloads/Temp.
- **Точка расширения** — `update` для подключения онлайн-баз LuxeOS.

## Возможности LuxeTweak

`wallpaper set`, `color <AARRGGBB>`, `taskbar on|off`, `glass on|off`,
`preset apply/list` (LuxeDark / LuxeLight / LuxeGlass / LuxeRetro), `status`.

---

## Глубокий ребрендинг (rebrand)

Скрипт `tools/rebrand.ps1` выполняется при первом запуске (через `postinstall.ps1`):

- **Безопасно (по умолчанию)** — меняет в реестре `ProductName` → `LuxeOS 8`,
  владельца/организацию → `LuxeOS`, и прописывает OEM-лого (показывается в
  «Свойства системы» / `Win+Pause` и «О программе»). Не ломает подписи, не брикит.
- **Глубоко (`-Deep`)** — патчит битмапы `winver.exe`/`shell32.dll` через
  Resource Hacker (`rh.exe`) и лого загрузки через HackBGRT. **ВНИМАНИЕ:** это
  ломает цифровые подписи системных файлов; нужно выключить Secure Boot и
  разрешить тестовые подписи (`bcdedit /set testsigning on`), иначе система
  может не загрузиться. Применяйте только в виртуалке и делайте снимок ДО.

```powershell
# в виртуалке, от админа:
.\rebrand.ps1            # безопасный ребрендинг
.\rebrand.ps1 -Deep      # + лого/winver (рискованно)
```

Лого-заставка: `tools/branding/logo.bmp` (генерируется `make-logo.ps1`).

## Что можно добавить

- Онлайн-обновление баз (`LuxeMalware.ps1 update` через HTTPS к серверу LuxeOS).
- Поведенческий анализ и on-access блокировка.
- Больше пресетов и живых применений без перезахода.
- Ребрендинг глубже: boot-логотип, winver, «About LuxeOS» (ресурс-хакинг).

---

### Технические идентификаторы, сохранённые как у Windows (не брендируются)
- Имя образа в `autounattend.xml`: **`Windows 8.1 Pro`** — должно совпадать с именем в `install.wim`, иначе Setup не выберет редакцию.
- Путь **`Windows\Setup\Scripts`** — Windows ищет `SetupComplete.cmd` именно там.
- Путь **`Windows Kits`** — расположение ADK (`oscdimg.exe`).
- Файлы `boot\etfsboot.com`, `efi\microsoft\boot\efisys.bin` — загрузчики Windows.
