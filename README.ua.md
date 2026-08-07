# Mini ERP – Procurement, Inventory and Sales (Міні ERP – Закупівлі, Склад та Продажі)

[English](README.md) | [Deutsch](README.de.md) | [Українська](README.ua.md)

[![SAP ABAP Cloud](https://img.shields.io/badge/SAP-ABAP%20Cloud-0FAAFF?style=flat-square&logo=sap)](https://www.sap.com)
[![SAP RAP](https://img.shields.io/badge/Model-SAP%20RAP%20(Managed)-0073C6?style=flat-square)](https://help.sap.com)
[![Clean Core](https://img.shields.io/badge/Architecture-Clean%20Core%20Compliant-green?style=flat-square)](#6-принципи-clean-core)
[![Status](https://img.shields.io/badge/Status-Master%20Data%20Complete%20%7C%20Transactions%20In%20Progress-orange?style=flat-square)](#3-статус-реалізації-та-план-робіт)

**Версія:** 1.0 (MVP)

---

## 1. Огляд проєкту

Mini ERP — це демонстраційна ERP-система, розроблена за допомогою моделі програмування SAP ABAP Cloud та SAP RESTful Application Programming Model (RAP) в середовищі SAP BTP ABAP Environment.

Проєкт реалізує спрощений процес закупівель, складського обліку та продажів, дотримуючись сучасних практик розробки SAP. Сюди входять принципи SAP Clean Core (чисте ядро), бізнес-об'єкти RAP Business Objects, ракурси CDS View Entities, сервіси OData V4 та SAP Fiori Elements.

Застосунок є портфоліо-проєктом, що демонструє готову до хмари (cloud-ready) розробку на ABAP, суворе розділення шарів архітектури та корпоративні шаблони проєктування (enterprise design patterns).

Детальна технічна архітектура та специфікації доменної моделі доступні в [Архітектура та технічний дизайн](docs/Architecture.ua.md).

---

## 2. Технологічний стек

- **Платформа:** SAP BTP ABAP Environment (ABAP-середовище SAP BTP)
- **IDE:** Eclipse ADT (ABAP Development Tools)
- **Модель програмування:** SAP RESTful Application Programming Model (RAP)
- **Моделювання даних:** ABAP Core Data Services / CDS View Entities (Сутності ракурсів CDS)
- **Персистентність:** Transparent Tables (Прозорі таблиці) з підтримкою RAP Draft (Чернеток RAP)
- **Сервіси:** OData V4 UI Services (Сервіси інтерфейсу користувача OData V4)
- **UI-фреймворк:** SAP Fiori Elements
- **Стандарт розробки:** SAP Clean Core / ABAP Cloud

---

## 3. Статус реалізації та план робіт

Проєкт структуровано на два основних етапи.

### Етап 1: Master Data Management (Управління основними даними) — Завершено
- **Company Code (Балансова одиниця):** Юридичні особи підприємства (введення ключа вручну).
- **Warehouse (Склад):** Фізичні місця зберігання, прив'язані до Company Codes (автоматична генерація ключа).
- **Business Partner (Бізнес-партнер):** Клієнти, постачальники або комбіновані контрагенти (автоматична генерація ключа).
- **Item Group (Група матеріалів):** Класифікація продуктів із призначенням ПДВ за замовчуванням (автоматична генерація ключа).
- **Item Master (Основні дані матеріалу):** Матеріальні продукти та нематеріальні послуги (автоматична генерація ключа).
- **VAT Rate (Ставка ПДВ):** Механізм конфігурації податків (автоматична генерація ключа).

### Етап 2: Transactional Engine & Inventory (Транзакційне ядро та складський облік) — У процесі розробки
- **Purchase Orders & Goods Receipts (Замовлення на закупівлю та Находження матеріалів):** Життєвий цикл закупівель із підтримкою часткових надходжень.
- **Sales Orders & Goods Issues (Замовлення на продаж та Відпуск матеріалів):** Життєвий цикл продажів із суворими перевірками залишків на складах.
- **Dynamic Stock Calculation (Динамічний розрахунок запасів):** Розрахунок інвентарю в реальному часі (`Запаси = Надходження - Відпуск`), який обчислюється динамічно за допомогою CDS View Entities без використання постійних таблиць запасів.

---

## 4. Ключові архітектурні особливості

### Гібридний механізм діапазонів номерів (`ZCL_MERP_NUM_RANGE_UTIL`)
- **Первинний розподіл ключів:** Стандартний SAP Number Range Object (NRO) API через `cl_numberrange_runtime`.
- **Резервний варіант DB Max:** Динамічний пошук через Open SQL, який сканує як активні таблиці, так і таблиці чернеток (`nmax`), для запобігання колізій ключів під час паралельних сесій користувачів із чернетками.
- **Синхронізація NRO:** Автоматичне вирівнювання інтервалів через `cl_numberrange_intervals` після виконання початкового завантаження даних (seed).

### Автоматичне успадкування податків та значень (`ZCL_MERP_MD_UTIL`)
- **Ієрархічне визначення ПДВ:** Код ПДВ для Item (Матеріалу) успадковується за ланцюжком: `Item Master` -> `Item Group Default` -> `Manual Fallback` (Введення вручну у разі відсутності).
- **Попередні перевірки видалення:** Валідація цілісності зв'язків, яка запобігає видаленню сутностей Master Data, якщо на них є посилання, до спрацьовування тригерів бази даних.

### Автоматичне початкове налаштування (`ZCL_MERP_INITIAL_SETUP`)
- Запускний клас консолі, що реалізує інтерфейс `IF_OO_ADT_CLASSRUN`.
- Наповнює початковими тестовими даними (seed data) всі 6 сутностей Master Data.
- Очищає як Active (Активні), так і RAP Draft (Чернетки) таблиці під час ініціалізації.
- Автоматично синхронізує рівні послідовності NRO для відображення завантажених записів.

---

## 5. Service Binding & UI Preview (Зв'язування сервісів та попередній перегляд UI)

Сервіс OData V4 `ZUI_MERP_O4` відкриває всі сутності Master Data для використання у SAP Fiori Elements.

---

## 6. Принципи Clean Core

- **Суворий обсяг ABAP Cloud:** Нульове використання застарілих інструкцій ABAP або невипущених стандартних API від SAP.
- **Можливості RAP Draft:** Вбудована обробка станів для транзакційної безстатусної (stateless) HTTP-комунікації.
- **Автоматичний аудит:** Уніфіковане заповнення полів аудиту (`CREATED_BY`, `CREATED_AT`, `LAST_CHANGED_AT` тощо).

---

## 7. Налаштування та запуск

1. Імпортуйте репозиторій у ваше середовище SAP BTP ABAP Environment за допомогою інструменту **abapGit** в Eclipse ADT.
2. Активуйте CDS View Entities, Behavior Definitions (Визначення поведінки) та Service Bindings (Зв'язування сервісів) в ієрархічному порядку.
3. Відкрийте Service Binding `ZUI_MERP_O4` і натисніть **Publish** (або **Unpublish / Publish**) для реєстрації локальної кінцевої точки OData V4.
4. Запустіть клас `ZCL_MERP_INITIAL_SETUP` в Eclipse ADT (`F9`) для заповнення початкових даних та синхронізації діапазонів номерів.
5. Перегляньте роботу застосунків за допомогою Fiori Elements Preview в редакторі Service Binding.

---

## 📄 Пов'язана документація
- 📘 [Архітектура та технічний дизайн](docs/Architecture.ua.md)
