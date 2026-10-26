(() => {
  "use strict";

  const MENU_KEY = "good-plate-menu-v1";
  const ORDERS_KEY = "good-plate-orders-v1";
  const statuses = ["received", "preparing", "ready", "completed", "cancelled"];
  const sampleMenu = [
    { id: "demo-toast", name: "Roasted tomato toast", category: "Small plates", description: "Sourdough, slow-roasted tomatoes, whipped ricotta and garden herbs.", price: 8.5, available: true, emoji: "🍅", barcode: "DEMO-001" },
    { id: "demo-chicken", name: "Crispy chicken sandwich", category: "Mains", description: "Buttermilk chicken, crunchy slaw, pickles and a bright house sauce.", price: 13, available: true, emoji: "🥪", barcode: "DEMO-002" },
    { id: "demo-bowl", name: "Market greens bowl", category: "Mains", description: "Greens, grains, crisp vegetables and lemon dressing.", price: 11.5, available: true, emoji: "🥗", barcode: "DEMO-003" },
    { id: "demo-fries", name: "Rosemary fries", category: "Sides", description: "Golden-cut potatoes with rosemary salt and garlic aioli.", price: 5, available: true, emoji: "🍟", barcode: "DEMO-004" },
    { id: "demo-cake", name: "Lemon olive-oil cake", category: "Something sweet", description: "Soft citrus cake finished with seasonal fruit.", price: 7, available: true, emoji: "🍰", barcode: "DEMO-005" },
    { id: "demo-cold-brew", name: "Cold brew", category: "Drinks", description: "Slow-steeped coffee, served over ice.", price: 4.5, available: true, emoji: "🧋", barcode: "DEMO-006" },
  ];
  const artColors = ["#f1e4c9", "#dce8d7", "#efded4", "#dfe6ed", "#eadfe9"];
  const app = document.querySelector("#main");
  const appShell = document.querySelector(".app-shell");
  const toastRegion = document.querySelector(".toast-region");
  const dishDialog = document.querySelector(".dish-dialog");
  const checkoutDialog = document.querySelector(".checkout-dialog");
  const productDialog = document.querySelector(".product-dialog");
  const confirmDialog = document.querySelector(".confirm-dialog");
  const state = { menu: [], orders: [], cart: {}, mode: "browse", staffTab: "menu", category: "Everything", search: "" };

  function loadList(key, fallback, validator) {
    const raw = localStorage.getItem(key);
    if (raw === null) return structuredClone(fallback);
    const value = JSON.parse(raw);
    if (!Array.isArray(value) || !value.every(validator)) throw new Error(`Saved data in ${key} is not valid.`);
    return value;
  }

  const validMenuItem = item => item && typeof item.id === "string" && typeof item.name === "string" &&
    typeof item.category === "string" && typeof item.description === "string" &&
    typeof item.price === "number" && typeof item.available === "boolean";
  const validOrder = order => order && typeof order.id === "string" &&
    typeof order.customer === "string" && Array.isArray(order.items) &&
    statuses.includes(order.status) && typeof order.createdAt === "string";

  function escapeHtml(value) {
    return String(value).replace(/[&<>"']/g, char => ({
      "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
    })[char]);
  }

  function money(value) {
    return `₹${Number(value).toFixed(2)}`;
  }

  function save(key, value) {
    try {
      localStorage.setItem(key, JSON.stringify(value));
      return true;
    } catch (error) {
      notify(`Could not save changes in this browser: ${error.message}`, "error");
      return false;
    }
  }

  function notify(message, kind = "success") {
    const toast = document.createElement("div");
    toast.className = "toast";
    toast.dataset.kind = kind;
    toast.textContent = message;
    toastRegion.append(toast);
    window.setTimeout(() => toast.remove(), 3800);
  }

  function cartCount() {
    return Object.values(state.cart).reduce((sum, quantity) => sum + quantity, 0);
  }

  function cartTotal() {
    return state.menu.reduce((sum, item) => sum + item.price * (state.cart[item.id] || 0), 0);
  }

  function changeQuantity(id, amount) {
    const next = (state.cart[id] || 0) + amount;
    if (next > 0) state.cart[id] = next;
    else delete state.cart[id];
    render();
  }

  function art(item, extraClass = "") {
    const color = artColors[Math.abs(hash(item.category)) % artColors.length];
    return `<div class="dish-art ${extraClass}" style="--dish-bg:${color}" aria-hidden="true"><span class="dish-emoji">${escapeHtml(item.emoji || "🍽️")}</span></div>`;
  }

  function hash(value) {
    let result = 0;
    for (let index = 0; index < value.length; index += 1) result = ((result << 5) - result + value.charCodeAt(index)) | 0;
    return result;
  }

  function render() {
    document.querySelector("[data-mode-label]").textContent = state.mode === "browse" ? "Staff view" : "Customer view";
    if (state.mode === "staff") renderStaff();
    else renderBrowse();
  }

  function renderBrowse() {
    const available = state.menu.filter(item => item.available);
    const categories = ["Everything", ...new Set(available.map(item => item.category).filter(Boolean))];
    if (!categories.includes(state.category)) state.category = "Everything";
    const query = state.search.trim().toLowerCase();
    const filtered = available.filter(item =>
      (state.category === "Everything" || item.category === state.category) &&
      (!query || `${item.name} ${item.description} ${item.category}`.toLowerCase().includes(query)));
    const grid = filtered.length
      ? filtered.map(item => browseCard(item)).join("")
      : `<div class="empty-state"><div class="empty-state-symbol" aria-hidden="true">${available.length ? "⌕" : "♨"}</div><h2>${available.length ? "No dishes found" : "Nothing on the menu yet"}</h2><p>${available.length ? "Try another search or menu section." : "The staff can add the first dish from Staff view."}</p></div>`;
    app.innerHTML = `
      <div class="menu-layout">
        <section class="menu-content" aria-labelledby="page-title">
          <h1 class="page-heading" id="page-title">Good things, made to order.</h1>
          <p class="heading-note">${available.length} ${available.length === 1 ? "dish" : "dishes"} on the board · Choose a dish to see what goes into it.</p>
          <div class="menu-tools">
            <label class="search-wrap"><span class="visually-hidden"></span><input class="search-input" type="search" placeholder="Find a dish" aria-label="Search menu" value="${escapeHtml(state.search)}"><button class="search-clear" type="button" data-action="clear-search" aria-label="Clear search" ${state.search ? "" : "hidden"}>×</button></label>
            <nav class="category-list" aria-label="Menu sections">${categories.map(category => `<button class="category-chip" type="button" data-action="category" data-category="${escapeHtml(category)}" aria-pressed="${category === state.category}">${escapeHtml(category)}</button>`).join("")}</nav>
          </div>
          <div class="dish-grid">${grid}</div>
        </section>
        ${renderReceipt()}
      </div>
      <div class="mobile-order-bar"><button class="button button-primary" type="button" data-action="checkout" ${cartCount() ? "" : "disabled"}><span>Review ${cartCount()} ${cartCount() === 1 ? "item" : "items"}</span><span>${money(cartTotal())}　→</span></button></div>`;
  }

  function browseCard(item) {
    const quantity = state.cart[item.id] || 0;
    return `<article class="dish-card">
      <button class="dish-art-button" type="button" data-action="details" data-id="${escapeHtml(item.id)}" aria-label="View details for ${escapeHtml(item.name)}">${art(item)}</button>
      <div class="dish-copy"><span class="dish-category">${escapeHtml(item.category)}</span>
        <button class="dish-title-button" type="button" data-action="details" data-id="${escapeHtml(item.id)}">${escapeHtml(item.name)}</button>
        <p class="dish-description">${escapeHtml(item.description || "Ask the kitchen for today’s details.")}</p>
        <div class="dish-card-bottom"><span class="dish-price">${money(item.price)}</span>
          ${quantity ? quantityControl(item.id, quantity, item.name) : `<button class="button button-soft" type="button" data-action="add" data-id="${escapeHtml(item.id)}">＋ Add</button>`}
        </div>
      </div>
    </article>`;
  }

  function quantityControl(id, quantity, name) {
    return `<span class="quantity-control" aria-label="${escapeHtml(name)} quantity">
      <button type="button" data-action="quantity" data-id="${escapeHtml(id)}" data-delta="-1" aria-label="Remove one ${escapeHtml(name)}">−</button>
      <output>${quantity}</output>
      <button type="button" data-action="quantity" data-id="${escapeHtml(id)}" data-delta="1" aria-label="Add one ${escapeHtml(name)}">＋</button>
    </span>`;
  }

  function renderReceipt() {
    const lines = state.menu.filter(item => state.cart[item.id]);
    return `<aside class="receipt-panel" aria-labelledby="receipt-title">
      <div class="receipt-heading"><h2 id="receipt-title">Your order</h2><span class="receipt-count">${cartCount()}</span></div>
      <p class="receipt-subtitle">A little something for the table.</p>
      <div class="receipt-items">${lines.length ? lines.map(item => `<div class="receipt-line"><div><strong>${escapeHtml(item.name)}</strong><small>${money(item.price)} each</small></div>${quantityControl(item.id, state.cart[item.id], item.name)}</div>`).join("") : `<p class="receipt-empty">Your receipt is waiting for its first dish.</p>`}</div>
      <div class="receipt-total"><span>Total</span><strong>${money(cartTotal())}</strong></div>
      <button class="button button-primary receipt-submit" type="button" data-action="checkout" ${lines.length ? "" : "disabled"}>Continue to details</button>
      <p class="receipt-footnote">Demo order · no payment taken</p>
    </aside>`;
  }

  function renderStaff() {
    const panel = state.staffTab === "menu" ? renderMenuManager() : renderKitchen();
    app.innerHTML = `<section aria-labelledby="staff-title">
      <div class="staff-heading"><div><h1 class="page-heading" id="staff-title">${state.staffTab === "menu" ? "Menu management" : "Kitchen orders"}</h1><p>Local demo · changes and tickets are saved in this browser.</p></div>
      ${state.staffTab === "menu" ? `<button type="button" class="button button-primary" data-action="new-product">＋ Add a dish</button>` : `<button type="button" class="button button-outline" data-action="refresh-orders">↻ Refresh orders</button>`}</div>
      <div class="staff-tabs" role="tablist" aria-label="Staff workspace">
        <button type="button" class="tab-button" role="tab" data-action="staff-tab" data-tab="menu" aria-selected="${state.staffTab === "menu"}">Menu (${state.menu.length})</button>
        <button type="button" class="tab-button" role="tab" data-action="staff-tab" data-tab="kitchen" aria-selected="${state.staffTab === "kitchen"}">Kitchen (${state.orders.filter(order => !["completed", "cancelled"].includes(order.status)).length})</button>
      </div>
      ${panel}</section>`;
  }

  function renderMenuManager() {
    if (!state.menu.length) return `<div class="empty-state"><div class="empty-state-symbol">♨</div><h2>Your menu is empty</h2><p>Add a dish to start accepting demo orders.</p></div>`;
    return `<div class="staff-list">${state.menu.map(item => `<article class="staff-dish">
      <div><h3>${escapeHtml(item.name)}</h3><p>${escapeHtml(item.category)} · ${money(item.price)}${item.description ? ` · ${escapeHtml(item.description)}` : ""}</p></div>
      <div class="staff-actions"><label class="availability"><input type="checkbox" data-action="availability" data-id="${escapeHtml(item.id)}" ${item.available ? "checked" : ""}> ${item.available ? "Available" : "Unavailable"}</label>
      <button class="button button-soft" type="button" data-action="edit-product" data-id="${escapeHtml(item.id)}">Edit</button>
      <button class="button button-danger" type="button" data-action="delete-product" data-id="${escapeHtml(item.id)}">Delete</button></div>
    </article>`).join("")}</div>`;
  }

  function renderKitchen() {
    if (!state.orders.length) return `<div class="empty-state"><div class="empty-state-symbol">▤</div><h2>The kitchen is quiet</h2><p>Demo orders placed from the customer menu will appear here with item quantities and kitchen notes.</p></div>`;
    return `<div class="order-list">${[...state.orders].sort((a, b) => b.createdAt.localeCompare(a.createdAt)).map(order => {
      const date = new Date(order.createdAt);
      const itemCount = Number(order.itemCount) || order.items.reduce((sum, item) => sum + Number(item.quantity || 0), 0);
      return `<article class="order-card">
        <div class="order-card-header"><strong class="order-customer">${escapeHtml(order.customer)}</strong>
          <span class="status-pill" data-status="${escapeHtml(order.status)}">${escapeHtml(statusLabel(order.status))}</span>
          <time class="order-time" datetime="${escapeHtml(order.createdAt)}">${Number.isNaN(date.valueOf()) ? "Date unavailable" : escapeHtml(date.toLocaleString())}</time>
          <strong class="order-total">${money(order.total || 0)}</strong></div>
        <div class="order-lines">${order.items.map(item => `<span class="order-item">${Number(item.quantity)} × ${escapeHtml(item.name)} · ${money(Number(item.price) * Number(item.quantity))}</span>`).join("")}</div>
        <p class="order-note">${order.requirements ? `Kitchen note: ${escapeHtml(order.requirements)}` : "Kitchen note: none"} · ${itemCount} ${itemCount === 1 ? "item" : "items"}</p>
        <label class="form-field" style="max-width:220px;margin-top:12px">Order status<select class="order-status-select" data-action="order-status" data-id="${escapeHtml(order.id)}">${statuses.map(status => `<option value="${status}" ${status === order.status ? "selected" : ""}>${escapeHtml(statusLabel(status))}</option>`).join("")}</select></label>
      </article>`;
    }).join("")}</div>`;
  }

  function statusLabel(status) {
    return status.charAt(0).toUpperCase() + status.slice(1);
  }

  function productById(id) {
    return state.menu.find(item => item.id === id);
  }

  function openDish(id) {
    const item = productById(id);
    if (!item) return;
    dishDialog.className = "modal dish-dialog";
    dishDialog.innerHTML = `<div class="modal-inner"><div class="modal-head"><div><h2 id="dish-dialog-title">${escapeHtml(item.name)}</h2><p>${escapeHtml(item.category)}</p></div><button class="icon-button" type="button" data-action="close-dialog" aria-label="Close">×</button></div>${art(item, "modal-art")}<p class="modal-description">${escapeHtml(item.description || "Ask the kitchen for today’s details.")}</p><div class="modal-footer"><strong class="modal-price">${money(item.price)}</strong><button class="button button-primary" type="button" data-action="add-from-details" data-id="${escapeHtml(item.id)}">＋ Add to order</button></div></div>`;
    dishDialog.showModal();
  }

  function openCheckout() {
    if (!cartCount()) return;
    checkoutDialog.className = "modal checkout-dialog";
    checkoutDialog.innerHTML = `<div class="modal-inner"><div class="modal-head"><div><h2 id="checkout-title">A name for the ticket</h2><p>Your demo order will be saved on this device only. No payment will be taken.</p></div><button class="icon-button" type="button" data-action="close-dialog" aria-label="Close">×</button></div>
      <form class="form-stack" id="checkout-form"><label class="form-field">Customer name<input name="customer" autocomplete="name" required maxlength="80" placeholder="Name on the order"></label><label class="form-field">Kitchen note (optional)<textarea name="requirements" maxlength="240" placeholder="Allergies or other order requirements"></textarea><span class="form-hint">The kitchen can see this with the order.</span></label><p class="form-error" aria-live="polite"></p><div class="checkout-summary"><span>${cartCount()} ${cartCount() === 1 ? "item" : "items"}</span><strong>${money(cartTotal())}</strong></div><button class="button button-primary form-submit" type="submit">Save demo order</button></form></div>`;
    checkoutDialog.showModal();
    checkoutDialog.querySelector("[name=customer]").focus();
  }

  function openProductForm(item) {
    const editing = Boolean(item);
    const product = item || { name: "", category: "Mains", description: "", price: "", barcode: "", available: true };
    productDialog.className = "modal product-dialog";
    productDialog.innerHTML = `<div class="modal-inner"><div class="modal-head"><div><h2 id="product-dialog-title">${editing ? "Edit dish" : "Add a dish"}</h2><p>Update what customers see on the sample menu.</p></div><button class="icon-button" type="button" data-action="close-dialog" aria-label="Close">×</button></div>
      <form class="form-stack" id="product-form" data-id="${escapeHtml(product.id || "")}">
        <label class="form-field">Dish name<input name="name" required maxlength="80" value="${escapeHtml(product.name)}" placeholder="e.g. Roasted tomato toast"></label>
        <label class="form-field">Menu section<input name="category" required maxlength="40" value="${escapeHtml(product.category)}" placeholder="Mains, Sides, Drinks"></label>
        <label class="form-field">Description<textarea name="description" maxlength="240" placeholder="Ingredients and helpful details">${escapeHtml(product.description)}</textarea></label>
        <label class="form-field">Price<input name="price" type="number" required min="0" step="0.01" value="${escapeHtml(product.price)}" inputmode="decimal"></label>
        <label class="form-field">Barcode <span class="form-hint">Optional</span><input name="barcode" maxlength="80" value="${escapeHtml(product.barcode || "")}" placeholder="Optional scan code"></label>
        <label class="availability"><input name="available" type="checkbox" ${product.available ? "checked" : ""}> Available to order</label>
        <p class="form-error" aria-live="polite"></p><button class="button button-primary form-submit" type="submit">${editing ? "Save changes" : "Add dish"}</button>
      </form></div>`;
    productDialog.showModal();
    productDialog.querySelector("[name=name]").focus();
  }

  function submitCheckout(form) {
    if (!form.reportValidity()) return;
    const customer = form.elements.customer.value.trim();
    if (!customer) {
      form.querySelector(".form-error").textContent = "Enter a name for the order.";
      form.elements.customer.focus();
      return;
    }
    const items = state.menu.filter(item => state.cart[item.id]).map(item => ({
      productId: item.id, name: item.name, price: item.price, quantity: state.cart[item.id],
    }));
    if (!items.length) return;
    const order = {
      id: typeof crypto.randomUUID === "function" ? crypto.randomUUID() : `${Date.now()}-${Math.random().toString(36).slice(2)}`,
      customer, requirements: form.elements.requirements.value.trim(), items,
      total: items.reduce((sum, item) => sum + item.price * item.quantity, 0),
      itemCount: items.reduce((sum, item) => sum + item.quantity, 0),
      status: "received", createdAt: new Date().toISOString(),
    };
    state.orders.push(order);
    if (!save(ORDERS_KEY, state.orders)) {
      state.orders.pop();
      return;
    }
    state.cart = {};
    checkoutDialog.close();
    render();
    notify(`Demo order saved for ${customer}.`);
  }

  function submitProduct(form) {
    if (!form.reportValidity()) return;
    const name = form.elements.name.value.trim();
    const category = form.elements.category.value.trim();
    const price = Number(form.elements.price.value);
    const barcode = form.elements.barcode.value.trim();
    const id = form.dataset.id || (typeof crypto.randomUUID === "function" ? crypto.randomUUID() : `${Date.now()}-${Math.random().toString(36).slice(2)}`);
    const duplicate = barcode && state.menu.some(item => item.barcode === barcode && item.id !== id);
    if (!name || !category || !Number.isFinite(price) || price < 0 || duplicate) {
      form.querySelector(".form-error").textContent = duplicate ? "That barcode is already in use." : "Check the dish name, section and price.";
      return;
    }
    const old = productById(id);
    const updated = {
      id, name, category, price, barcode,
      description: form.elements.description.value.trim(),
      available: form.elements.available.checked,
      emoji: old?.emoji || "🍽️",
    };
    const nextMenu = old
      ? state.menu.map(item => item.id === id ? updated : item)
      : [...state.menu, updated];
    if (!save(MENU_KEY, nextMenu)) return;
    state.menu = nextMenu;
    productDialog.close();
    render();
    notify(old ? "Dish updated." : "Dish added to the menu.");
  }

  function requestDeleteProduct(id) {
    const item = productById(id);
    if (!item) return;
    confirmDialog.className = "modal confirm-dialog";
    confirmDialog.innerHTML = `<div class="modal-inner"><div class="modal-head"><div><h2 id="confirm-title">Remove this dish?</h2><p>${escapeHtml(item.name)} will disappear from the customer menu. Saved orders keep their item details.</p></div><button class="icon-button" type="button" data-action="close-dialog" aria-label="Close">×</button></div><div class="modal-footer"><button class="button button-outline" type="button" data-action="close-dialog">Keep dish</button><button class="button button-danger" type="button" data-action="confirm-delete" data-id="${escapeHtml(id)}">Delete dish</button></div></div>`;
    confirmDialog.showModal();
  }

  function deleteProduct(id) {
    const item = productById(id);
    if (!item) return;
    const next = state.menu.filter(product => product.id !== id);
    if (!save(MENU_KEY, next)) return;
    state.menu = next;
    delete state.cart[id];
    render();
    notify(`${item.name} removed from the menu.`);
  }

  function setAvailability(id, available) {
    const next = state.menu.map(item => item.id === id ? { ...item, available } : item);
    if (!save(MENU_KEY, next)) return;
    state.menu = next;
    render();
    notify(available ? "Dish is available to order." : "Dish marked unavailable.");
  }

  function setOrderStatus(id, status) {
    if (!statuses.includes(status)) return;
    const next = state.orders.map(order => order.id === id ? { ...order, status } : order);
    if (!save(ORDERS_KEY, next)) return;
    state.orders = next;
    render();
    notify(`Order status updated to ${statusLabel(status)}.`);
  }

  app.addEventListener("input", event => {
    if (event.target.matches(".search-input")) {
      state.search = event.target.value;
      const selectionStart = event.target.selectionStart;
      renderBrowse();
      const next = app.querySelector(".search-input");
      next.focus();
      next.setSelectionRange(selectionStart, selectionStart);
    }
  });

  app.addEventListener("change", event => {
    const { action, id } = event.target.dataset;
    if (action === "availability") setAvailability(id, event.target.checked);
    if (action === "order-status") setOrderStatus(id, event.target.value);
  });

  appShell.addEventListener("click", event => {
    const button = event.target.closest("[data-action]");
    if (!button) return;
    const { action, id, delta, category, tab } = button.dataset;
    if (action === "toggle-mode") {
      state.mode = state.mode === "browse" ? "staff" : "browse";
      render();
    } else if (action === "home") {
      event.preventDefault();
      state.mode = "browse";
      render();
      window.scrollTo({ top: 0, behavior: "smooth" });
    } else if (action === "category") {
      state.category = category;
      render();
    } else if (action === "clear-search") {
      state.search = "";
      render();
      app.querySelector(".search-input").focus();
    } else if (action === "add" || action === "quantity") {
      changeQuantity(id, action === "add" ? 1 : Number(delta));
    } else if (action === "details") {
      openDish(id);
    } else if (action === "add-from-details") {
      dishDialog.close();
      changeQuantity(id, 1);
    } else if (action === "checkout") {
      openCheckout();
    } else if (action === "staff-tab") {
      state.staffTab = tab;
      render();
    } else if (action === "new-product") {
      openProductForm(null);
    } else if (action === "edit-product") {
      openProductForm(productById(id));
    } else if (action === "delete-product") {
      requestDeleteProduct(id);
    } else if (action === "confirm-delete") {
      confirmDialog.close();
      deleteProduct(id);
    } else if (action === "close-dialog") {
      button.closest("dialog").close();
    } else if (action === "refresh-orders") {
      notify("Order list refreshed.");
      renderStaff();
    }
  });

  checkoutDialog.addEventListener("submit", event => {
    if (event.target.id !== "checkout-form") return;
    event.preventDefault();
    submitCheckout(event.target);
  });
  productDialog.addEventListener("submit", event => {
    if (event.target.id !== "product-form") return;
    event.preventDefault();
    submitProduct(event.target);
  });
  for (const dialog of [dishDialog, checkoutDialog, productDialog]) {
    dialog.addEventListener("click", event => {
      if (event.target === dialog) dialog.close();
    });
  }
  window.addEventListener("storage", event => {
    try {
      if (event.key === MENU_KEY && event.newValue) state.menu = loadList(MENU_KEY, [], validMenuItem);
      if (event.key === ORDERS_KEY && event.newValue) state.orders = loadList(ORDERS_KEY, [], validOrder);
      render();
    } catch (error) {
      notify(`Could not refresh shared browser data: ${error.message}`, "error");
    }
  });

  try {
    state.menu = loadList(MENU_KEY, sampleMenu, validMenuItem);
    state.orders = loadList(ORDERS_KEY, [], validOrder);
    if (localStorage.getItem(MENU_KEY) === null && !save(MENU_KEY, state.menu)) {
      app.innerHTML = `<div class="empty-state"><h2>Browser storage is unavailable</h2><p>Enable local storage in your browser to save menu changes and demo orders.</p></div>`;
      return;
    }
    render();
  } catch (error) {
    app.innerHTML = `<div class="empty-state"><div class="empty-state-symbol">!</div><h2>Saved demo data could not be opened</h2><p>${escapeHtml(error.message)}. Clear this site's local storage to restore the sample menu.</p></div>`;
  }
})();
