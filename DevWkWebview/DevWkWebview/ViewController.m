//
//  ViewController.m
//  DevWkWebview
//
//  Created by yiqiwang(王一棋) on 2019/10/14.
//  Copyright © 2019 melody5417. All rights reserved.
//

#import "ViewController.h"
#import <WebKit/WebKit.h>

@interface ViewController () <WKUIDelegate, WKNavigationDelegate>

@property (nonatomic, strong) WKWebView *webView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // setup
    [self setupNaivationBar];
    [self setupWebView];

    // load
    [self loadRequest];

}

- (void)setupNaivationBar {
    UIBarButtonItem *backButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStyleDone target:self action:@selector(onBack)];
    UIBarButtonItem *forwardButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"forward" style:UIBarButtonItemStyleDone target:self action:@selector(onForward)];
    self.navigationItem.leftBarButtonItems = @[backButtonItem, forwardButtonItem];
}

- (void)setupWebView {
    [self.view addSubview:self.webView];
}

#pragma mark - Action

- (void)onBack {
    [self.webView goBack];
}

- (void)onForward {
    [self.webView goForward];
}

- (void)loadRequest {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://www.chinadaily.com.cn"]];
    [self.webView loadRequest:request];
}

#pragma mark - WKUIDelegate // 主要处理JS脚本，确认框，警告框等

#pragma mark - WKNavigationDelegate // 主要处理一些跳转、加载处理操作

// 页面开始加载时调用
- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(null_unspecified WKNavigation *)navigation {
    NSLog(@"%s", __FUNCTION__);
}

// 页面加载完成之后调用
- (void)webView:(WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation {
    NSLog(@"%s", __FUNCTION__);
}

// 页面加载失败时调用
// 通常来说如果页面出现不存在等问题，会走这里，如果需要对空白页面进行处理，在这里处理
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error {
    NSLog(@"%s", __FUNCTION__);
}

// 页面跳转失败
- (void)webView:(WKWebView *)webView didFailNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error {
    NSLog(@"%s", __FUNCTION__);
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
    if (((NSHTTPURLResponse *)navigationResponse.response).statusCode == 200) {
        decisionHandler (WKNavigationResponsePolicyAllow);
    }else {
        decisionHandler(WKNavigationResponsePolicyCancel);
    }
}

//// 需要响应身份验证时调用 同样在block中需要传入用户身份凭证
//- (void)webView:(WKWebView *)webView didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential))completionHandler {
//}

// webView进程被终止时调用
- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView API_AVAILABLE(macosx(10.11), ios(9.0)) {
    NSLog(@"%s", __FUNCTION__);
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

        _webView = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:config];
        _webView.scrollView.bounces = YES;
        _webView.allowsBackForwardNavigationGestures = YES;

        _webView.UIDelegate = self;
        _webView.navigationDelegate = self;
    }
    return _webView;
}

@end
