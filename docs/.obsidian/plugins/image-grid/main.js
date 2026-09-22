var __defProp = Object.defineProperty;
var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
var __getOwnPropNames = Object.getOwnPropertyNames;
var __hasOwnProp = Object.prototype.hasOwnProperty;
var __export = (target, all) => {
  for (var name in all)
    __defProp(target, name, { get: all[name], enumerable: true });
};
var __copyProps = (to, from, except, desc) => {
  if (from && typeof from === "object" || typeof from === "function") {
    for (let key of __getOwnPropNames(from))
      if (!__hasOwnProp.call(to, key) && key !== except)
        __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
  }
  return to;
};
var __toCommonJS = (mod) => __copyProps(__defProp({}, "__esModule", { value: true }), mod);

// src/main.ts
var main_exports = {};
__export(main_exports, {
  default: () => ImageGridPlugin
});
module.exports = __toCommonJS(main_exports);
var import_obsidian2 = require("obsidian");

// src/types.ts
var DEFAULT_CONFIG = {
  columns: 3,
  gap: 4
};

// src/parser.ts
var IMAGE_REGEX = /^!\[\[([^\]|]+?)(?:\|(\d+))?\]\]$/;
var CONFIG_REGEX = /^(\w+)\s*:\s*(.+)$/;
var CONFIG_PARSERS = {
  columns: (value, config) => {
    const parsed = parseInt(value, 10);
    if (parsed > 0) config.columns = parsed;
  },
  gap: (value, config) => {
    const parsed = parseInt(value, 10);
    if (parsed >= 0) config.gap = parsed;
  }
};
function parseGridBlock(source) {
  const config = { ...DEFAULT_CONFIG };
  const images = [];
  let configSection = true;
  const lines = source.split("\n").map((line) => line.trim()).filter((line) => line.length > 0);
  for (const line of lines) {
    const imageMatch = line.match(IMAGE_REGEX);
    if (imageMatch) {
      configSection = false;
      images.push({
        path: imageMatch[1],
        size: imageMatch[2] ? parseInt(imageMatch[2], 10) : null
      });
      continue;
    }
    if (configSection) {
      const configMatch = line.match(CONFIG_REGEX);
      if (configMatch) {
        const key = configMatch[1].toLowerCase();
        const parser = CONFIG_PARSERS[key];
        if (parser) {
          parser(configMatch[2].trim(), config);
        } else {
          console.warn(`[image-grid] Unknown config key: "${key}"`);
        }
        continue;
      }
    }
    console.warn(`[image-grid] Skipping unrecognized line: "${line}"`);
  }
  return { config, images };
}

// src/renderer.ts
var import_obsidian = require("obsidian");
function openLightbox(src, alt) {
  const overlay = document.createElement("div");
  overlay.addClass("image-grid-lightbox");
  const img = overlay.createEl("img", {
    attr: { src, alt },
    cls: "image-grid-lightbox-img"
  });
  const dismiss = () => overlay.remove();
  overlay.addEventListener("click", (e) => {
    if (e.target !== img) dismiss();
  });
  const onKeydown = (e) => {
    if (e.key === "Escape") {
      dismiss();
      document.removeEventListener("keydown", onKeydown);
    }
  };
  document.addEventListener("keydown", onKeydown);
  document.body.appendChild(overlay);
}
function renderGrid(result, container, app, sourcePath) {
  var _a;
  const { config, images } = result;
  if (images.length === 0) {
    const empty = container.createEl("p", {
      text: "No images specified.",
      cls: "image-grid-empty"
    });
    empty.setAttribute("role", "status");
    return;
  }
  const grid = container.createDiv({ cls: "image-grid" });
  grid.style.gridTemplateColumns = `repeat(${config.columns}, 1fr)`;
  grid.style.gap = `${config.gap}px`;
  for (const image of images) {
    const cell = grid.createDiv({ cls: "image-grid-cell" });
    const file = app.metadataCache.getFirstLinkpathDest(image.path, sourcePath);
    if (!file) {
      cell.createEl("span", {
        text: `Image not found: ${image.path}`,
        cls: "image-grid-error"
      });
      continue;
    }
    const img = cell.createEl("img", {
      cls: "image-grid-img",
      attr: {
        src: file instanceof import_obsidian.TFile ? app.vault.getResourcePath(file) : "",
        alt: image.path,
        loading: "lazy"
      }
    });
    if (image.size) {
      img.style.maxWidth = `${image.size}px`;
    }
    const imgSrc = (_a = img.getAttribute("src")) != null ? _a : "";
    cell.addEventListener("click", () => {
      openLightbox(imgSrc, image.path);
    });
  }
}

// src/main.ts
var ImageGridPlugin = class extends import_obsidian2.Plugin {
  onload() {
    this.registerMarkdownCodeBlockProcessor(
      "image-grid",
      (source, el, ctx) => {
        const result = parseGridBlock(source);
        renderGrid(result, el, this.app, ctx.sourcePath);
      }
    );
  }
};

/* nosourcemap */