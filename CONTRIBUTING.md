# Contributing to VYRE Secure Access

Спасибо, что хотите внести свой вклад в VYRE! ❤️

## Как форкнуть и склонировать репозиторий

1. Нажмите **Fork** в верхнем правом углу [репозитория](https://github.com/toptestsoft/vyre-mobile)
2. Клонируйте ваш форк локально:
```sh
git clone https://github.com/<ваш-username>/vyre-mobile.git
cd vyre-mobile
```

## Установка зависимостей

```sh
flutter pub get
```

## Запуск линтера и форматтера

```sh
# Проверка качества кода
flutter analyze

# Форматирование кода
flutter format .
```

## Создание ветки и Pull Request

1. Создайте новую ветку для вашего изменения:
```sh
git checkout -b feature/название-изменения
```
2. Внесите изменения и закоммитьте:
```sh
git add .
git commit -m "feat: добавлена поддержка X"
```
3. Отправьте ветку:
```sh
git push origin feature/название-изменения
```
4. Откройте Pull Request через веб-интерфейс GitHub.

## Требования к сообщениям коммитов

Используем **Conventional Commits**:

```
feat: добавлена поддержка Reality
fix: исправлена ошибка подписки
docs: обновлен README
refactor: оптимизированы запросы
test: добавлены unit-тесты
chore: обновлены зависимости
```
