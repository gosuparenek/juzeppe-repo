"use strict";
const grid = document.getElementById("packages");
const status = document.getElementById("catalog-status");
const search = document.getElementById("search");
let packages = [];

function element(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
}

function validPackage(item) {
  return item && typeof item.id === "string" &&
    /^[a-z0-9_-]+$/.test(item.id) &&
    typeof item.name === "string" &&
    typeof item.version === "string" &&
    typeof item.package === "string" &&
    /^packages\/[a-z0-9_.-]+\.juz$/i.test(item.package);
}

function card(item) {
  const article = element("article", "card");
  const top = element("div", "package-top");
  const icon = element("div", "pixel-icon");
  icon.setAttribute("aria-hidden", "true");
  const rows = Array.isArray(item.icon) && item.icon.length === 6 &&
    item.icon.every(row => typeof row === "string" && /^[01]{6}$/.test(row))
      ? item.icon : ["111111", "100001", "101101", "101101", "100001", "111111"];
  for (const pixel of rows.join("")) icon.append(element("span", pixel === "1" ? "on" : ""));
  const identity = element("div");
  identity.append(element("h3", "", item.name_ru || item.name),
    element("p", "", item.id + " · " + (item.author || "JuzeppeOS")));
  top.append(icon, identity, element("span", "pill", "v" + item.version));
  const description = element("p", "package-description", item.description_ru || item.description || "Приложение JuzeppeOS.");
  const command = element("div", "install-command");
  const value = "jpkg install " + item.id;
  const copy = element("button", "copy", "Копировать");
  copy.type = "button";
  copy.dataset.copy = value;
  command.append(element("code", "", value), copy);
  const controls = element("div", "card-buttons");
  const download = element("a", "button secondary", "Скачать .juz ↓");
  download.href = item.package;
  download.download = item.id + ".juz";
  controls.append(download);
  article.append(top, description, command, controls);
  return article;
}

function render() {
  const query = search.value.trim().toLocaleLowerCase("ru");
  const filtered = packages.filter(item =>
    [item.id, item.name, item.name_ru, item.description, item.description_ru]
      .some(value => typeof value === "string" && value.toLocaleLowerCase("ru").includes(query))
  );
  grid.replaceChildren();
  status.textContent = filtered.length + " из " + packages.length + " приложений";
  if (!filtered.length) grid.append(element("p", "empty", "Ничего не найдено."));
  else for (const item of filtered) grid.append(card(item));
}

async function copyText(button) {
  const text = button.dataset.copy;
  try {
    await navigator.clipboard.writeText(text);
  } catch {
    const area = element("textarea");
    area.value = text;
    area.style.position = "fixed";
    area.style.opacity = "0";
    document.body.append(area);
    area.select();
    const copied = document.execCommand("copy");
    area.remove();
    if (!copied) return;
  }
  const previous = button.textContent;
  button.textContent = "Скопировано";
  setTimeout(() => { button.textContent = previous; }, 1400);
}

document.addEventListener("click", event => {
  const button = event.target.closest("[data-copy]");
  if (button) copyText(button);
});
search.addEventListener("input", render);
fetch("index.json", { cache: "no-cache" })
  .then(response => {
    if (!response.ok) throw new Error("Каталог недоступен");
    return response.json();
  })
  .then(index => {
    if (index.format !== 1 || !Array.isArray(index.packages)) throw new Error("Неверный каталог");
    packages = index.packages.filter(validPackage);
    render();
  })
  .catch(() => {
    status.textContent = "Не удалось загрузить каталог";
    grid.replaceChildren(element("p", "empty", "Попробуйте обновить страницу или откройте index.json напрямую."));
  });
