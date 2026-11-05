enum MallDestination {
  home('商城', 'https://mall.bilibili.com/'),
  category('分类', 'https://mall.bilibili.com/category.html?noTitleBar=1'),
  cart(
    '购物车',
    'https://mall.bilibili.com/neul/index.html?page=mall_cart&noTitleBar=1',
  ),
  account(
    '商城账户',
    'https://mall.bilibili.com/neul/index.html?page=box_me&noTitleBar=1',
  );

  const MallDestination(this.label, this.url);
  final String label;
  final String url;

  static MallDestination? fromUri(Uri uri) {
    if (uri.host != 'mall.bilibili.com') return null;
    return switch (uri.path) {
      '/' || '/index.html' => home,
      '/category.html' => category,
      '/cart.html' => cart,
      '/neul/index.html' => switch (uri.queryParameters['page']) {
        'mall_cart' => cart,
        'box_me' => account,
        _ => null,
      },
      _ => null,
    };
  }
}

enum MallTicketDestination {
  activity(
    '漫展演出',
    'https://mall.bilibili.com/neul-next/ticket/home.html?noTitleBar=1',
  ),
  movie(
    '电影',
    'https://mall.bilibili.com/neul-next/ticket/movieHome.html?noTitleBar=1',
  ),
  collection(
    '票务收藏',
    'https://mall.bilibili.com/neul-next/ticket/collection.html?noTitleBar=1',
  ),
  order('订单中心', 'https://mall.bilibili.com/orderlist.html?noTitleBar=1');

  const MallTicketDestination(this.label, this.url);
  final String label;
  final String url;
}

enum MallPageKind {
  product('商品详情'),
  search('搜索'),
  catalog('分类'),
  cart('购物车');

  const MallPageKind(this.label);
  final String label;
}

abstract final class MallNavigation {
  static MallPageKind? pageKind(Uri uri) {
    if (!isOfficial(uri) || uri.host != 'mall.bilibili.com') return null;
    if (isProductDetail(uri)) return MallPageKind.product;
    if (const {
      '/category.html',
      '/list.html',
      '/newlist.html',
    }.contains(uri.path)) {
      return MallPageKind.catalog;
    }
    if (uri.path == '/neul-next/index.html' &&
        uri.queryParameters['page'] == 'flow_searchResult') {
      return MallPageKind.search;
    }
    if (uri.path == '/neul/index.html' &&
        uri.queryParameters['page'] == 'mall_cart') {
      return MallPageKind.cart;
    }
    return null;
  }

  static bool opensSecondary(Uri current, Uri target) =>
      pageKind(target) != null && pageKind(target) != pageKind(current);

  static bool isProductDetail(Uri uri) =>
      isOfficial(uri) &&
      uri.host == 'mall.bilibili.com' &&
      uri.queryParameters['itemsId']?.isNotEmpty == true &&
      (uri.path == '/detail.html' ||
          (uri.path == '/neul-next/detailuniversal/detail.html' &&
              uri.queryParameters['page'] == 'detailuniversal_detail'));

  static bool isOfficial(Uri uri) =>
      uri.scheme == 'https' &&
      uri.port == 443 &&
      const {
        'mall.bilibili.com',
        'show.bilibili.com',
        'passport.bilibili.com',
      }.contains(uri.host);

  static Uri normalize(Uri uri) {
    // The official homepage links this public list alias. The same page was
    // verified on mall.bilibili.com; keep its parameters and B-site session.
    if (uri.scheme == 'https' &&
        uri.port == 443 &&
        uri.host == 'www.biligo.com' &&
        uri.path == '/list.html') {
      return uri.replace(host: 'mall.bilibili.com');
    }
    if (uri.scheme == 'bilibili' && uri.host == 'mall' && uri.path == '/web') {
      final target = Uri.tryParse(uri.queryParameters['url'] ?? '');
      if (target != null && isOfficial(target)) return normalize(target);
    }
    if (uri.scheme == 'http' &&
        const {
          'mall.bilibili.com',
          'show.bilibili.com',
          'passport.bilibili.com',
        }.contains(uri.host)) {
      uri = uri.replace(scheme: 'https');
    }
    if (uri.host == 'mall.bilibili.com' && uri.path == '/cart.html') {
      return uri.replace(
        scheme: 'https',
        path: '/neul/index.html',
        queryParameters: {
          ...uri.queryParametersAll,
          'page': ['mall_cart'],
        },
      );
    }
    return uri;
  }
}
