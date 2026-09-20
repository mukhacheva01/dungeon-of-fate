# Web build

После push в `main` GitHub Actions соберёт Godot Web export и опубликует его через GitHub Pages.

Ожидаемый адрес: `https://mukhacheva01.github.io/dungeon-of-fate/`

Если GitHub попросит выбрать источник Pages, выбери **GitHub Actions** в Settings → Pages. Дальше каждый push в `main` будет обновлять игру автоматически.

Локально Web export не запускается без Godot export templates, поэтому сборка намеренно вынесена в GitHub Actions. Это экономит около 1.2 ГБ диска и гарантирует сборку на точной версии Godot 4.7.2.
