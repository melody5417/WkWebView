//
//  ViewController.m
//  DevWkWebview
//
//  Created by yiqiwang(王一棋) on 2019/10/14.
//  Copyright © 2019 melody5417. All rights reserved.
//

#import "ViewController.h"
#import <WebKit/WebKit.h>

#define WEBVIEW_JS_BRIDGE   @"jsBridge"

// 避免循环引用
@interface WeakScriptMessageDelegate : NSObject <WKScriptMessageHandler>

@property (nonatomic, weak) id<WKScriptMessageHandler> scriptDelegate;

@end

@implementation WeakScriptMessageDelegate

- (instancetype)initWithDelegate:(id<WKScriptMessageHandler>)scriptDelegate {
    self = [super init];
    if (self) {
        self.scriptDelegate = scriptDelegate;
    }
    return self;
}

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([self.scriptDelegate respondsToSelector:@selector(userContentController:didReceiveScriptMessage:)]) {
        [self.scriptDelegate userContentController:userContentController didReceiveScriptMessage:message];
    }
}

@end

@interface ViewController () <WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler>

@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) UILabel *errorLabel;

@end

@implementation ViewController

// MARK: Life Cycle

- (void)viewDidLoad {
    [super viewDidLoad];

    // setup
    [self setupNaivationBar];
    [self setupWebView];
    [self setupProgressView];
    [self setupErrorView];

    // load
//    [self loadRequest];
    [self loadLocal];
//    [self loadRequestWithCookie];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if (self.webView) {
        if (self.webView.configuration.userContentController.userScripts.count > 0) {
            [self removeAllScriptMessageHandle];
        }

        [self addScriptMessageHandle];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [self removeAllScriptMessageHandle];
}

- (void)dealloc {
    [self.webView removeObserver:self forKeyPath:@"estimatedProgress" context:nil];

    [self removeAllScriptMessageHandle];
}

#pragma mark - Setup

- (void)setupNaivationBar {
    UIBarButtonItem *backButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStyleDone target:self action:@selector(onBack)];
    UIBarButtonItem *forwardButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"forward" style:UIBarButtonItemStyleDone target:self action:@selector(onForward)];
    self.navigationItem.leftBarButtonItems = @[backButtonItem, forwardButtonItem];

    UIBarButtonItem *rightButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"call JS" style:UIBarButtonItemStyleDone target:self action:@selector(nativeToJS)];
    self.navigationItem.rightBarButtonItem = rightButtonItem;
}

- (void)setupWebView {
    [self.view addSubview:self.webView];

    [self.webView addObserver:self forKeyPath:@"estimatedProgress" options:NSKeyValueObservingOptionNew context:nil];
    [self.webView addObserver:self forKeyPath:@"title" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)setupProgressView {
    [self.view addSubview:self.progressView];
}

- (void)setupErrorView {
    [self.view addSubview:self.errorLabel];
}

#pragma mark - Progress

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"estimatedProgress"]) {
        [self.progressView setAlpha:1.0f];
        [self.progressView setProgress:self.webView.estimatedProgress animated:YES];
        if (self.webView.estimatedProgress >= 1.0f) {
            [UIView animateWithDuration:0.3 animations:^{
                [self.progressView setAlpha:0];
            } completion:^(BOOL finished) {
                [self.progressView setProgress:0];
                [self.progressView setHidden:YES];
            }];
        }
    } else if ([keyPath isEqualToString:@"title"] && object == self.webView) {
        self.navigationItem.title = self.webView.title;
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark - Cookie

// Cookie 持久化文件地址在 iOS 9+ 上在NSLibraryDirectory/Cookies

// 注入 cookie
// 此方式既可以解决首个request无法携带cookie的问题
// 也可以解决跨域 cookie 丢失的问题
- (void)injectCookieWithCompletion:(void (^)(void))completion {
    NSString *userId = @"testUserId";
    NSString *cookieScript = [NSString stringWithFormat:@"document.cookie = '%@=%@;path=/';", @"x-user-id", userId];
    [self.webView evaluateJavaScript:cookieScript completionHandler:^(id _Nullable object, NSError * _Nullable error) {
        if (completion) { completion(); }
    }];
}

// 只能解决首次加载 cookie 注入的问题，跨域 cookie 会丢失
- (void)loadRequestWithCookie {
    NSMutableDictionary *cookieDic = [NSMutableDictionary dictionary];
    NSMutableString *cookieValue = [NSMutableString stringWithFormat:@""];

    NSHTTPCookieStorage *cookieJar = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *cookie in [cookieJar cookies]) {
        [cookieDic setObject:cookie.value forKey:cookie.name];
    }
    [cookieDic setValue:@"test-cookie-request" forKey:@"testCookie"];

    // cookie重复，先放到字典进行去重，再进行拼接
    for (NSString *key in cookieDic) {
        NSString *appendString = [NSString stringWithFormat:@"%@=%@;", key, [cookieDic valueForKey:key]];
        [cookieValue appendString:appendString];
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://www.chinadaily.com.cn"]];
    [request addValue:cookieValue forHTTPHeaderField:@"Cookie"];

    [self.webView loadRequest:request];
}

#pragma mark - Action

- (void)onBack {
    if ([self.webView canGoBack]) {
        if ([self.webView.backForwardList.currentItem.title isEqualToString:@"XXX"]) {
            // back to root
            [self.webView goToBackForwardListItem:[self.webView.backForwardList backList].firstObject];
        } else {
            [self.webView goBack];
        }
    } else {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (void)onForward {
    [self.webView goForward];
}

- (void)loadRequest {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://www.chinadaily.com.cn"]];
    [self.webView loadRequest:request];
}

- (void)loadLocal {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"index.html" ofType:nil];
    NSString *htmlString = [[NSString alloc]initWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    [self.webView loadHTMLString:htmlString baseURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]]];
}

#pragma mark - WKUIDelegate // 主要处理JS脚本，确认框，警告框等

#pragma mark - WKNavigationDelegate // 主要处理一些跳转、加载处理操作

// 页面开始加载时调用
- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(null_unspecified WKNavigation *)navigation {
    NSLog(@"%s", __FUNCTION__);

    [self.errorLabel setHidden:YES];
    [self.progressView setHidden:NO];
    self.progressView.transform = CGAffineTransformMakeScale(1.0, 1.5);
    [self.view bringSubviewToFront:self.progressView];
}

// 页面加载完成之后调用
- (void)webView:(WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation {
    NSLog(@"%s", __FUNCTION__);

    self.errorLabel.hidden = YES;
    self.progressView.hidden = YES;
    self.title = self.webView.title;

    [self injectCookieWithCompletion:^{
        NSLog(@"注入 cookie 完成");
    }];
}

// 页面加载失败时调用
// 通常来说如果页面出现不存在等问题，会走这里，如果需要对空白页面进行处理，在这里处理
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error {
    NSLog(@"%s", __FUNCTION__);

    self.progressView.hidden = YES;
    self.errorLabel.hidden = NO;
    [self.view bringSubviewToFront:self.errorLabel];
}

// 页面跳转失败
- (void)webView:(WKWebView *)webView didFailNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error {
    NSLog(@"%s", __FUNCTION__);
    self.progressView.hidden = YES;
    self.errorLabel.hidden = YES;
}

// 当内容开始返回时调用
- (void)webView:(WKWebView *)webView didCommitNavigation:(null_unspecified WKNavigation *)navigation {
    NSLog(@"%s", __FUNCTION__);
}

// 接收到服务器跳转请求即服务重定向时之后调用
- (void)webView:(WKWebView *)webView didReceiveServerRedirectForProvisionalNavigation:(null_unspecified WKNavigation *)navigation {
    NSLog(@"%s", __FUNCTION__);
}

// 请求之前，对于即将跳转的HTTP请求头信息和相关信息来决定是否跳转
// 用户点击网页上的链接，需要打开新页面时，将先调用这个方法。
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSLog(@"%s", __FUNCTION__);

    // 如果是跳转一个新页面
    if (navigationAction.targetFrame == nil) {
        [webView loadRequest:navigationAction.request];
    }
    decisionHandler(WKNavigationActionPolicyAllow);
}

// 根据客户端受到的服务器响应头以及response相关信息来决定是否可以跳转
- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler {
    NSLog(@"%s", __FUNCTION__);
    if ([navigationResponse.response isKindOfClass:[NSHTTPURLResponse class]]) {
        if (((NSHTTPURLResponse *)navigationResponse.response).statusCode == 200) {
            decisionHandler (WKNavigationResponsePolicyAllow);
        } else {
            decisionHandler(WKNavigationResponsePolicyCancel);
        }
    } else {
        decisionHandler (WKNavigationResponsePolicyAllow);
    }
}

//// 需要响应身份验证时调用 同样在block中需要传入用户身份凭证
//- (void)webView:(WKWebView *)webView didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential))completionHandler {
//}

// webView进程被终止时调用
- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView API_AVAILABLE(macosx(10.11), ios(9.0)) {
    NSLog(@"%s", __FUNCTION__);
}

#pragma mark - WKScriptMessageHandler

// @abstract Invoked when a script message is received from a webpage.
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    NSLog(@"name:%@ \n body:%@ \n frameInfo:%@ \n",message.name, message.body, message.frameInfo);

    if (![message.name isEqualToString:WEBVIEW_JS_BRIDGE]) { return; }
    if (![message.body isKindOfClass:[NSDictionary class]]) { return; }

    NSDictionary *body = (NSDictionary *)message.body;
    if ([[body objectForKey:@"func"] isEqualToString:@"print"]) {
        NSLog(@"%@", [body objectForKey:@"param"]);
    }
}

#pragma mark - Native vs JS

- (void)removeAllScriptMessageHandle {
    [self.webView.configuration.userContentController removeScriptMessageHandlerForName:WEBVIEW_JS_BRIDGE];
}

- (void)addScriptMessageHandle {
    // JS 调用 Native
    // 对 JS 调用的方法进行监听，最好集中处理
    // 使用自定义的ScripMessageHandler 避免循环引用
    // WKUserContentController可以理解为调度器，WKScriptMessage则是携带的数据。
    WeakScriptMessageDelegate *weakScriptMessageDelegate = [[WeakScriptMessageDelegate alloc] initWithDelegate:self];
    [self.webView.configuration.userContentController addScriptMessageHandler:weakScriptMessageDelegate name:WEBVIEW_JS_BRIDGE];
}

// native 调用 JS
- (void)nativeToJS {
    // WKWebview 禁止长按(超链接、图片、文本...)弹出效果 todo yiqi 好像不好用
    [self.webView evaluateJavaScript:@"document.documentElement.style.webkitTouchCallout='none';" completionHandler:nil];
    [self.webView evaluateJavaScript:@"document.documentElement.style.webkitUserSelect='none';" completionHandler:nil];

    [self.webView evaluateJavaScript:@"changeColor()" completionHandler:^(id _Nullable data, NSError * _Nullable error) {
        if (!error) {
            NSLog(@"改变HTML的背景色");
        } else {
            NSLog(@"%s %@", __FUNCTION__, error);
        }
    }];

    // 注意：参数必须要有''单引号扩起来
    [self.webView evaluateJavaScript:[NSString stringWithFormat:@"changeName('%@')", @"native"] completionHandler:^(id _Nullable data, NSError * _Nullable error) {
        if (!error) {
            NSLog(@"改变名字");
        } else {
            NSLog(@"%s %@", __FUNCTION__, error);
        }
    }];
}

#pragma mark - Getter

- (WKWebView *)webView {
    if (!_webView) {
        WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];

        WKPreferences *preference = [[WKPreferences alloc] init];
        preference.minimumFontSize = 5;
        preference.javaScriptEnabled = YES;
        preference.javaScriptCanOpenWindowsAutomatically = YES;
        config.preferences = preference;

        config.allowsInlineMediaPlayback = YES;
        config.mediaTypesRequiringUserActionForPlayback = YES;
        config.allowsPictureInPictureMediaPlayback = YES;

        // User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 12_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) DevWkWebView
        config.applicationNameForUserAgent = @"DevWkWebView";

        WKUserContentController *userController = [[WKUserContentController alloc] init];
        // js注入
        NSString *jSString = @"";
        WKUserScript *wkUScript = [[WKUserScript alloc] initWithSource:jSString injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES];
        [userController addUserScript:wkUScript];
        config.userContentController = userController;

        _webView = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:config];
        _webView.scrollView.bounces = YES;
        _webView.allowsBackForwardNavigationGestures = YES;

        _webView.UIDelegate = self;
        _webView.navigationDelegate = self;
    }
    return _webView;
}

- (UIProgressView *)progressView {
    if (!_progressView) {
        _progressView = [[UIProgressView alloc] initWithFrame:CGRectMake(0, 100, self.view.frame.size.width, 5)];
        _progressView.tintColor = UIColor.blueColor;
        _progressView.trackTintColor = UIColor.clearColor;
    }
    return _progressView;
}

- (UILabel *)errorLabel {
    if (!_errorLabel) {
        _errorLabel = [[UILabel alloc] initWithFrame:self.view.bounds];
        _errorLabel.font = [UIFont systemFontOfSize:30];
        _errorLabel.textAlignment = NSTextAlignmentCenter;
        _errorLabel.text = @"加载网页失败";
    }
    return _errorLabel;
}

@end
