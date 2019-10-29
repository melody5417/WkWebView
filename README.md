# iOS开发：WKWebView 开发总结

## WKWebView 基础开发
### 初始化 加载 goback goforward
iOS 8.0+ 和 OSX 10.10+ 适用。
初始化： ```init(frame:configuration:)```
加载本地 HTML： ```loadHTMLString(_:baseURL:)```
加载web页面:
	* 请求： ``` load(_:) ```
	* 停止加载： ```stopLoading()```
	* 加载状态： ```isLoading```
	* 前进 
		```
		canGoForward
		goForward()
		```
	* 后退
		```
		canGoBack
		goBack()
		```


### 各种代理 WKUIDelegate
### 各种 UI 展示， 进度条， title， 各种跳转
## native 和 webview 交互
## Cookie
## UserAgent
## H5 调试， safari 调试，charles 
## 参考
[APPLE WKWebView](https://developer.apple.com/documentation/webkit/wkwebview)