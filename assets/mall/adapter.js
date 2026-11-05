(function installMallAdapter() {
  'use strict';
  if (window.top !== window || !['https://mall.bilibili.com', 'https://show.bilibili.com'].includes(location.origin)) return;
  if (window.__piliMallAdapter) return;
  // History notifications can arrive before the new document has a body.
  if (!document.body) {
    if (!window.__piliMallAdapterPending) {
      window.__piliMallAdapterPending = true;
      document.addEventListener('DOMContentLoaded', () => {
        window.__piliMallAdapterPending = false;
        installMallAdapter();
      }, {once: true});
    }
    return;
  }

  const isMall = location.origin === 'https://mall.bilibili.com';
  const legacyPages = new Set(['/', '/index.html', '/category.html', '/list.html', '/newlist.html', '/detail.html', '/orderlist.html', '/addresslist.html', '/neul-next/ticket/home.html', '/neul-next/ticket/movieHome.html', '/neul-next/ticket/collection.html', '/neul-next/ticket-renovation/detail.html']);
  const neulPages = new Set(['mall_cart', 'box_me', 'aftersale_list', 'aftersale_listRefund', 'aftersale_aftersaleList']);
  const ticketPages = new Set(['/m/platform/home.html', '/m/platform/search.html', '/m/platform/detail.html', '/h5/detail.html']);
  const recognized = () => isMall ? legacyPages.has(location.pathname) ||
    (location.pathname === '/neul/index.html' && neulPages.has(new URL(location.href).searchParams.get('page'))) ||
    (location.pathname === '/neul-next/detailuniversal/detail.html' && new URL(location.href).searchParams.get('page') === 'detailuniversal_detail') ||
    (location.pathname === '/neul-next/index.html' && new URL(location.href).searchParams.get('page') === 'flow_searchResult') : ticketPages.has(location.pathname);
  if (!recognized()) return;

  const root = document.documentElement;
  const style = document.createElement('style');
  style.id = 'piliplus-mall-adapter';
  style.textContent = `
    html[data-pp-mall] [data-pp-nav], html[data-pp-mall] [data-pp-nav-spacer],
    html[data-pp-mall] [data-pp-promotion], html[data-pp-mall] [data-pp-promotion-row] { display:none!important; }
    html[data-pp-mall] [data-pp-raised] { bottom:max(var(--pp-original-bottom),var(--pp-overlay))!important; }
    html[data-pp-mall] [data-pp-ticket-modal] { height:calc(100% - var(--pp-overlay))!important; }
    html[data-pp-mall] [data-pp-search-filter], html[data-pp-mall] [data-pp-search-filter] .filter-board,
    html[data-pp-mall] [data-pp-search-filter] .board-wrapper { max-height:calc(100vh - var(--pp-overlay))!important; }
    html[data-pp-mall] [data-pp-scroll] { padding-bottom:calc(var(--pp-original-padding) + var(--pp-overlay))!important; scroll-padding-bottom:var(--pp-overlay); }
  `;
  document.head.appendChild(style);
  let config = {width: 0, bottom: 0};
  let homeStyle;
  let scheduled = false;
  const tracked = new Set();
  const filterGeometry = new WeakMap();
  // Weeko G2ShapeDrawable's paired cubic corners, top-only for the web sheet.
  // Recompute on actual geometry changes through the existing event scheduler.
  const shapeFilter = element => {
    const w = element.offsetWidth, h = element.offsetHeight;
    if (!w || !h) return;
    const r = Math.min(32 * (parseFloat(root.style.getPropertyValue('--pp-unit')) || 1), w / 2, h);
    const geometry = `${w},${h},${r}`;
    if (filterGeometry.get(element) === geometry) return;
    const path = [`M ${r} 0`, `L ${w-r} 0`];
    const corner = (x0,y0,vx0,vy0,x1,y1,vx1,vy1) => {
      const mx=(x0+x1)/2+(vx0-vx1)*.32, my=(y0+y1)/2+(vy0-vy1)*.32;
      path.push(`C ${x0+vx0*.28} ${y0+vy0*.28} ${x0+vx0*.64} ${y0+vy0*.64} ${mx} ${my}`,
        `C ${x1-vx1*.64} ${y1-vy1*.64} ${x1-vx1*.28} ${y1-vy1*.28} ${x1} ${y1}`);
    };
    corner(w-r,0,r,0,w,r,0,r);
    path.push(`L ${w} ${h}`, `L 0 ${h}`, `L 0 ${r}`);
    corner(0,r,0,-r,r,0,r,0);
    path.push('Z');
    element.style.clipPath = `path('${path.join(' ')}')`;
    filterGeometry.set(element, geometry);
  };
  const candidates = '.bottom-main,.bili-bottom,.bil-cart-footer.bottom-fixed,.bottom,.popup-container-wrapper,.scroll-container,.scroll-view-content,.category-part-container,a.item,.footer-menu,.footer-menu-wrapper,.footer-tab,.bili-modal,.franky-popup_box,#app > .header,.home-main,.home-search-bar,.search-result-wrap,.filter-wrap,.detail-container-wrap,.product-info-area,.bottom-bar-module,.bil-cart,#cartFooter,.main-goods-container';
  const mark = (element, attribute) => {
    if (!element.hasAttribute(attribute)) element.setAttribute(attribute, '');
    tracked.add(element);
  };
  const pad = element => {
    if (!element || element.hasAttribute('data-pp-scroll')) return;
    element.style.setProperty('--pp-original-padding', getComputedStyle(element).paddingBottom);
    mark(element, 'data-pp-scroll');
  };
  const raise = element => {
    if (element.hasAttribute('data-pp-raised')) return;
    const computed = getComputedStyle(element);
    if (computed.position !== 'fixed' && computed.position !== 'sticky') return;
    element.style.setProperty('--pp-original-bottom', computed.bottom === 'auto' ? '0px' : computed.bottom);
    mark(element, 'data-pp-raised');
  };
  const promotionLink = element => element.matches('a.item') && element.protocol === 'https:' &&
    ['www.biligo.com', 'mall.bilibili.com'].includes(element.hostname) &&
    element.pathname === '/neul/index.html' &&
    ['mall_tryoutmissevanlist', 'mall_tryoutmangalist'].includes(new URLSearchParams(element.search).get('page'));
  const promotionRow = element => {
    if (!element?.matches('.container')) return;
    const onlyPromotions = element.children.length > 0 && [...element.children].every(promotionLink) &&
      [...element.childNodes].every(node => node.nodeType !== Node.TEXT_NODE || !node.textContent.trim());
    if (onlyPromotions) mark(element, 'data-pp-promotion-row');
    else element.removeAttribute('data-pp-promotion-row');
  };
  const inspect = element => {
    if (element.matches('.search-result-wrap,.filter-wrap,.detail-container-wrap,.product-info-area,.bottom-bar-module,.bil-cart,#cartFooter,.main-goods-container,.scroll-view-content')) schedule();
    if (isMall && ['/', '/index.html'].includes(location.pathname)) {
      if (element.matches('#app > .header')) {
        if (element.children.length === 1 && element.firstElementChild.matches('.content') &&
            element.textContent.trim() === '会员购' && !element.querySelector('a,button,input,i,[role="button"]')) mark(element, 'data-pp-home-title');
        else element.removeAttribute('data-pp-home-title');
      }
      if (element.matches('.home-main,.home-search-bar')) schedule();
    }
    if (element.matches('.footer-tab') &&
        ['.bili-icon-home', '.bili-icon-movie', '.bili-icon-collection', '.bili-icon-order'].every(selector => element.querySelector(`.bili-nav-bar > .bili-nav-item ${selector}`))) {
      mark(element, 'data-pp-nav');
      const parent = element.parentElement;
      if (parent.matches('.bottom') && parent.children.length === 1 &&
          [...parent.childNodes].every(node => node.nodeType !== Node.TEXT_NODE || !node.textContent.trim())) mark(parent, 'data-pp-nav-spacer');
    }
    if (!isMall || location.pathname === '/neul-next/ticket-renovation/detail.html') {
      if (element.matches('.footer-container > .footer-menu') && element.querySelector('.action-container')) raise(element);
      if (element.matches('.footer-container > .footer-menu-wrapper') && element.querySelector('.footer-menu .action-container')) raise(element);
      if (element.matches('.bili-modal') && element.querySelector('.bili-modal-box') && getComputedStyle(element).position === 'fixed') mark(element, 'data-pp-ticket-modal');
      if (element.matches('.scroll-container')) pad(element.firstElementChild);
      return;
    }
    if (location.pathname === '/neul-next/index.html' && element.matches('.franky-popup_box.is-bottom') && element.querySelector('.filter-board .bottom-btn-group')) {
      raise(element);
      mark(element, 'data-pp-search-filter');
      schedule();
    }
    if (element.matches('.franky-popup_box.is-bottom') && element.querySelector('.sku-container')) {
      raise(element);
      mark(element, 'data-pp-sku-popup');
    }
    if (element.tagName === 'A' && (element.matches('a.item') || element.hasAttribute('data-pp-promotion'))) {
      if (promotionLink(element)) mark(element, 'data-pp-promotion');
      else element.removeAttribute('data-pp-promotion');
      promotionRow(element.parentElement);
    }
    if (element.matches('.bottom-main,.bili-bottom') &&
        ['.icon-index', '.icon-category', '.icon-cart', '.icon-order'].every(selector => element.querySelector(selector))) {
      mark(element, 'data-pp-nav');
      const spacer = element.parentElement.querySelector('.bottom-empty');
      if (spacer) mark(spacer, 'data-pp-nav-spacer');
    } else if (element.matches('.bil-cart-footer.bottom-fixed') ||
        (['/detail.html', '/neul-next/detailuniversal/detail.html'].includes(location.pathname) && element.matches('.bottom') && element.querySelector('.bottom-buy,.bottom-add,.bottom-buy-button,.buy-cart-button'))) {
      raise(element);
    } else if (element.matches('.popup-container-wrapper') && element.querySelector('.sku-container')) {
      raise(element);
    }
    if (element.matches('.scroll-container')) pad(element.firstElementChild);
    if (element.matches('.scroll-view-content')) pad(element);
    if (element.matches('.category-part-container')) pad(element);
  };
  const inspectTree = node => {
    if (!(node instanceof Element)) return;
    if (node.matches(candidates)) inspect(node);
    node.querySelectorAll(candidates).forEach(inspect);
    const parent = node.closest('.popup-container-wrapper,.bottom-main,.bili-bottom,.bottom,.footer-menu,.footer-menu-wrapper,.footer-tab,.bili-modal,.franky-popup_box,#app > .header');
    if (parent) inspect(parent);
    const row = node.closest('[data-pp-promotion-row]');
    if (row) promotionRow(row);
  };
  const apply = () => {
    scheduled = false;
    if (!recognized()) {
      root.removeAttribute('data-pp-mall');
      root.removeAttribute('data-pp-page');
      return;
    }
    root.setAttribute('data-pp-mall', '');
    // Android logical pixels and CSS pixels differ when a page has its own
    // viewport width. Do not use screen density as the conversion factor.
    const scale = config.width > 0 ? window.innerWidth / config.width : 0;
    const value = `${Math.max(0, config.bottom) * scale}px`;
    if (root.style.getPropertyValue('--pp-overlay') !== value) root.style.setProperty('--pp-overlay', value);
    root.style.setProperty('--pp-unit', `${scale || 1}px`);
    const home = isMall && ['/', '/index.html'].includes(location.pathname) &&
      document.querySelector('#app > .franky-scroll-view .head-container > .home-search-bar .bili-search-wrap') &&
      document.querySelector('#app > .franky-scroll-view .home-main');
    const query = new URL(location.href).searchParams;
    let page = home ? 'home' : null;
    if (isMall && location.pathname === '/category.html' && document.querySelector('.category-main .category-part-container') && document.querySelector('.header .search-input')) page = 'category';
    if (isMall && location.pathname === '/neul-next/index.html' && query.get('page') === 'flow_searchResult' && document.querySelector('.search-result-wrap .header-sticky .header-wrap') && document.querySelector('.search-result-wrap .filter-wrap')) page = 'search';
    if (isMall && ['/list.html', '/newlist.html'].includes(location.pathname) && document.querySelector('#app .main-goods-container') && document.querySelector('#app .main-filter-bar')) page = 'list';
    if (isMall && ['/detail.html', '/neul-next/detailuniversal/detail.html'].includes(location.pathname) && document.querySelector('.detail-container-wrap .product-info-area') && document.querySelector('.detail-container-wrap .bottom-bar-module .buy-cart-button')) page = 'detail';
    if (isMall && location.pathname === '/neul/index.html' && query.get('page') === 'mall_cart' && document.querySelector('.bil-cart #cartHeader') && document.querySelector('.bil-cart #cartFooter .footer-content')) page = 'cart';
    if (page && homeStyle && config.theme) root.setAttribute('data-pp-page', page);
    else root.removeAttribute('data-pp-page');
    if (page === 'search') {
      const height = `${document.querySelector('.search-result-wrap .header-sticky').getBoundingClientRect().height}px`;
      if (root.style.getPropertyValue('--pp-search-header-height') !== height) root.style.setProperty('--pp-search-header-height', height);
      document.querySelectorAll('[data-pp-search-filter] .filter-board').forEach(shapeFilter);
    }
    root.toggleAttribute('data-pp-inner-scroll', !!document.querySelector('.search-result-wrap .scroll-view-content,.bil-cart .shop-item .scroll-view-content'));
  };
  const schedule = () => {
    if (!scheduled) {
      scheduled = true;
      requestAnimationFrame(apply);
    }
  };
  const scan = () => {
    if (!recognized()) { schedule(); return; }
    inspectTree(document.body);
    pad(document.body);
    for (const element of tracked) if (!element.isConnected) tracked.delete(element);
    schedule();
  };
  const observer = new MutationObserver(records => {
    if (!recognized()) return;
    for (const record of records) {
      if (record.type === 'childList') {
        record.addedNodes.forEach(inspectTree);
        if (record.target instanceof Element && record.target.matches('.container')) promotionRow(record.target);
      }
      else if (record.target instanceof Element && (record.target.matches(candidates) || record.target.hasAttribute('data-pp-promotion'))) inspect(record.target);
    }
  });
  observer.observe(document.body, {childList:true, subtree:true, attributes:true, attributeFilter:['class','href']});
  const historyChanged = () => { scan(); };
  for (const name of ['pushState', 'replaceState']) {
    const original = history[name];
    history[name] = function(...args) {
      const result = Reflect.apply(original, this, args);
      historyChanged();
      return result;
    };
  }
  window.addEventListener('popstate', historyChanged);
  window.addEventListener('resize', schedule);
  window.visualViewport?.addEventListener('resize', schedule);
  window.__piliMallAdapter = {
    update(next) {
      const geometryChanged = config.width !== next.width || config.bottom !== next.bottom;
      config = next;
      if (next.homeStyle && !homeStyle) {
        homeStyle = document.createElement('style');
        homeStyle.id = 'piliplus-mall-home';
        homeStyle.textContent = next.homeStyle;
        document.head.appendChild(homeStyle);
      }
      for (const [name, value] of Object.entries(next.theme ?? {})) {
        if (root.style.getPropertyValue(`--pp-${name}`) !== String(value)) root.style.setProperty(`--pp-${name}`, String(value));
      }
      if (geometryChanged) scan();
      else schedule();
    },
    dismissOverlay() {
      if (!recognized()) return false;
      const selectors = isMall && !location.pathname.startsWith('/neul-next/ticket') ? '.popup-container-wrapper .popup-close,.franky-popup_box > .popup-container > .popup-close,.search-board .cancel,.franky-popup_box .filter-board .filter-close,.pswp--open .pswp__button--close' : '.bili-modal .bili-modal-close,.bili-modal .bili-icon-fold,.pswp--open .pswp__button--close';
      const buttons = [...document.querySelectorAll(selectors)].reverse();
      for (const button of buttons) {
        const panel = button.closest('.popup-container-wrapper,.search-board,.bili-modal,.pswp--open,.franky-popup_box');
        const rect = button.getBoundingClientRect();
        if (getComputedStyle(panel).display !== 'none' && getComputedStyle(panel).visibility !== 'hidden' && rect.width > 0 && rect.height > 0) {
          button.click();
          return true;
        }
      }
      return false;
    },
  };
  scan();
})();
