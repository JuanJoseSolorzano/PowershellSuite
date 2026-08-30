# 📅 Calendar Module

A small **calendar CLI** for PowerShell — inspired by tools like `khal`. Display any
month, create and list **events**, and manage a simple **to-do list**, all from the
terminal. Data is persisted to a local JSON file so your events and to-dos survive
between sessions.

Source: [`lib/calendar.psm1`](calendar.psm1)


## 🚀 Loading the module

The module is imported automatically by the suite. It is listed in `$INTERNAL_MODULES`
in [`Profile.ps1`](../Profile.ps1), so once your PowerShell profile is set up it loads on
every new session.

To load it manually (e.g. after editing it):

```powershell
Import-Module "$env:USERPROFILE\...\Powershell_Suite\lib\calendar.psm1" -Force -DisableNameChecking
```

> ℹ️ Requires **PowerShell 7.4+** (same as the rest of the suite).


## ⚙️ Configuration & data storage

Events and to-dos are stored in a single JSON file:

```
lib/utils/calendar_data.json
```

- The file and its `utils` folder are **created automatically** on first use.
- You never need to edit it by hand, but it is plain JSON if you ever want to back it up,
  sync it, or inspect it.

Structure:

```json
{
  "events": [
    {
      "Id": "6b67c5",
      "Title": "Team sync",
      "Date": "2026-08-29",
      "StartTime": "14:00",
      "EndTime": "15:00",
      "Location": "Room 1",
      "Description": "",
      "Created": "2026-08-29T20:33:42"
    }
  ],
  "todos": [
    {
      "Id": "c52c6f",
      "Title": "Finish report",
      "Due": "2026-08-30",
      "Priority": "High",
      "Done": false,
      "Created": "2026-08-29T20:33:42",
      "Completed": null
    }
  ]
}
```

**Changing where data is stored:** the path is defined by `Get-CalendarDataPath` in
[`calendar.psm1`](calendar.psm1). Edit that function if you want to point the store at a
synced folder (OneDrive, a Git repo, etc.).


## 🗓️ Month view

```powershell
Cal                    # current month
Cal August             # by month name
Cal Aug                # by abbreviation
Cal 8                  # by number
Cal August 2026        # month + year
Cal 8 2026 -MondayFirst  # start the week on Monday
```

| Parameter      | Description                                          | Default        |
| -------------- | ---------------------------------------------------- | -------------- |
| `-Month`       | Month as **name**, **abbreviation** or **number**    | current month  |
| `-Year`        | Year to display                                      | current year   |
| `-MondayFirst` | Start the week on Monday instead of Sunday           | off (Sunday)   |

### 🎨 Day colors (legend)

| Marker            | Meaning                                    |
| ----------------- | ------------------------------------------ |
| 🟩 green highlight | today                                      |
| 🔵 cyan           | day has an **event**                        |
| 🟡 yellow         | day has a **pending to-do** (by due date)   |
| 🟣 magenta        | day has **both** an event and a to-do       |


## 📌 Events

### Create an event

```powershell
Add-CalendarEvent "Team sync" tomorrow 14:00 15:00 -Location "Room 1"
Add-CalendarEvent "Dentist" 2026-09-03 09:30
Add-CalendarEvent "All-day workshop" 2026-09-10   # no time = all-day
```

| Position / Parameter | Description                                              | Default |
| -------------------- | ------------------------------------------------------- | ------- |
| `Title` (1)          | Short description (**required**)                         | —       |
| `Date` (2)           | `today`, `tomorrow`, `yesterday`, `yyyy-MM-dd`, or any parseable date | `today` |
| `Time` (3)           | Start time, e.g. `14:00`                                 | none    |
| `EndTime` (4)        | End time, e.g. `15:30`                                   | none    |
| `-Location`          | Where it takes place                                    | none    |
| `-Description`       | Longer note                                             | none    |

### List events

```powershell
Show-CalendarEvents                 # upcoming (today onward)
Show-CalendarEvents -All            # every event
Show-CalendarEvents -Month August   # a whole month
Show-CalendarEvents -Date 2026-08-29  # a single day
```

Events are grouped by day and show a short **id** in parentheses for removal.

### Remove an event

```powershell
Remove-CalendarEvent 6b67c5   # use the id shown in the listing
```


## ✅ To-do list

### Add a to-do

```powershell
Add-CalendarTodo "Finish report" tomorrow -Priority High
Add-CalendarTodo "Buy milk"                       # no due date, Medium priority
Add-CalendarTodo "Renew license" 2026-09-15 -Priority Low
```

| Position / Parameter | Description                                     | Default  |
| -------------------- | ----------------------------------------------- | -------- |
| `Title` (1)          | What needs to be done (**required**)            | —        |
| `Due` (2)            | `today`, `tomorrow`, `yyyy-MM-dd`, etc.         | none     |
| `-Priority`          | `Low`, `Medium` or `High`                       | `Medium` |

### List to-dos

```powershell
Show-CalendarTodos          # pending only (sorted by priority, then due date)
Show-CalendarTodos -All     # pending + completed
Show-CalendarTodos -Done    # completed only
```

Priority is color-coded: **High** 🔴, **Medium** 🟡, **Low** ⚪.

### Complete / remove a to-do

```powershell
Complete-CalendarTodo c52c6f   # mark done
Remove-CalendarTodo c52c6f     # delete
```


## 🧭 Agenda overview

A single screen that combines the month view, upcoming events and pending to-dos —
similar to `khal`'s default view.

```powershell
Show-Agenda            # current month
Show-Agenda September  # a specific month
```


## 🔤 Aliases

Short, CLI-style names are provided for everyday use:

| Alias        | Command                 |
| ------------ | ----------------------- |
| `agenda`     | `Show-Agenda`           |
| `event-add`  | `Add-CalendarEvent`     |
| `events`     | `Show-CalendarEvents`   |
| `event-del`  | `Remove-CalendarEvent`  |
| `todo-add`   | `Add-CalendarTodo`      |
| `todos`      | `Show-CalendarTodos`    |
| `todo-done`  | `Complete-CalendarTodo` |
| `todo-del`   | `Remove-CalendarTodo`   |

> `Cal` is already short and is used as-is (no `cal` alias, to avoid shadowing the function).

Example using aliases:

```powershell
event-add "Standup" today 09:00 09:15
todo-add "Review PR" today -Priority High
agenda
```


## 📆 Accepted formats

**Months** (for `Cal` / `-Month`): full name (`August`), abbreviation (`Aug`), partial
name (`Au`), or number (`1`–`12`).

**Dates** (for `Date` / `Due`): the keywords `today`, `tomorrow`, `yesterday`, the ISO
format `yyyy-MM-dd`, or any date your system culture can parse.


## 🧩 Command summary

| Task            | Command                 | Alias       |
| --------------- | ----------------------- | ----------- |
| Show a month    | `Cal`                   | —           |
| Overview        | `Show-Agenda`           | `agenda`    |
| Add event       | `Add-CalendarEvent`     | `event-add` |
| List events     | `Show-CalendarEvents`   | `events`    |
| Delete event    | `Remove-CalendarEvent`  | `event-del` |
| Add to-do       | `Add-CalendarTodo`      | `todo-add`  |
| List to-dos     | `Show-CalendarTodos`    | `todos`     |
| Complete to-do  | `Complete-CalendarTodo` | `todo-done` |
| Delete to-do    | `Remove-CalendarTodo`   | `todo-del`  |


## 👤 Author

- **Solorzano, Juan Jose**
