//
//  ViewController.m
//  FEPay
//
//  Created by keso on 16/10/14.
//  Copyright © 2016年 FlyElephant. All rights reserved.
//

#import "ViewController.h"
#import <StoreKit/StoreKit.h>

//沙盒测试环境验证
static NSString *SANDBOX=@"https://sandbox.itunes.apple.com/verifyReceipt";
//正式环境验证
static NSString *AppStore=@"https://buy.itunes.apple.com/verifyReceipt";

@interface ViewController () <SKPaymentTransactionObserver,SKProductsRequestDelegate>

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)applePayAction:(UIButton *)sender {
    if([SKPaymentQueue canMakePayments]){
        NSArray *product = [[NSArray alloc] initWithObjects:@"flylephant01",nil];
        
        NSSet *nsset = [NSSet setWithArray:product];
        SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:nsset];
        request.delegate = self;
        [request start];
    }else{
        NSLog(@"FlyElephant-不允许进行苹果内购");
    }
}

#pragma mark - SKProductsRequestDelegate
//接收到产品返回信息
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    NSLog(@"productsRequest----didReceiveResponse-------------------");
    NSArray *product = response.products;
    if([product count] == 0){
        return;
    }
    
    NSLog(@"productID:%@", response.invalidProductIdentifiers);
    NSLog(@"产品付费数量:%lu",(unsigned long)[product count]);
    
    for (SKProduct *pro in product) {
        NSLog(@"%@", [pro description]);
        NSLog(@"%@", [pro localizedTitle]);
        NSLog(@"%@", [pro localizedDescription]);
        NSLog(@"%@", [pro price]);
        NSLog(@"%@", [pro productIdentifier]);
        
        SKPayment *payment = [SKPayment paymentWithProduct:pro];
        
        NSLog(@"FlyElephant--发送苹果内购");
        [[SKPaymentQueue defaultQueue] addPayment:payment];
    }
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    NSLog(@"request---didFailWithError");
}

- (void)requestDidFinish:(SKRequest *)request {
    NSLog(@"requestDidFinish");
}

#pragma mark - SKPaymentTransactionObserver

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {
    for(SKPaymentTransaction *tran in transactions){
        switch (tran.transactionState) {
            case SKPaymentTransactionStatePurchased:{
                NSLog(@"交易完成");
                [self verifyPurchaseWithPaymentTransaction];
                [[SKPaymentQueue defaultQueue] finishTransaction:tran];
            }
                break;
            case SKPaymentTransactionStatePurchasing:
                NSLog(@"商品添加进列表");
                break;
            case SKPaymentTransactionStateRestored:{
                NSLog(@"已经购买过商品");
                [[SKPaymentQueue defaultQueue] finishTransaction:tran];
            }
                break;
            case SKPaymentTransactionStateFailed:{
                NSLog(@"交易失败");
                [[SKPaymentQueue defaultQueue] finishTransaction:tran];
            }
                break;
            default:
                break;
        }
    }
}

//交易结束
- (void)completeTransaction:(SKPaymentTransaction *)transaction{
    NSLog(@"交易结束");
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}


//验证购买，避免越狱软件模拟苹果请求达到非法购买问题

-(void)verifyPurchaseWithPaymentTransaction{
    //从沙盒中获取交易凭证并且拼接成请求体数据
    NSURL *receiptUrl=[[NSBundle mainBundle] appStoreReceiptURL];
    NSData *receiptData=[NSData dataWithContentsOfURL:receiptUrl];
    
    NSString *receiptString=[receiptData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];//转化为base64字符串
    
    NSString *bodyString = [NSString stringWithFormat:@"{\"receipt-data\" : \"%@\"}", receiptString];//拼接请求数据
    NSData *bodyData = [bodyString dataUsingEncoding:NSUTF8StringEncoding];

    //创建请求到苹果官方进行购买验证
    NSURL *url=[NSURL URLWithString:SANDBOX];
    NSMutableURLRequest *requestM=[NSMutableURLRequest requestWithURL:url];
    requestM.HTTPBody=bodyData;
    requestM.HTTPMethod=@"POST";
    //创建连接并发送同步请求
    NSError *error=nil;
    NSData *responseData=[NSURLConnection sendSynchronousRequest:requestM returningResponse:nil error:&error];
    if (error) {
        NSLog(@"验证购买过程中发生错误，错误信息：%@",error.localizedDescription);
        return;
    }
    NSDictionary *dic=[NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingAllowFragments error:nil];
    NSLog(@"%@",dic);
    if([dic[@"status"] intValue]==0){
        NSDictionary *dicReceipt= dic[@"receipt"];
        NSDictionary *dicInApp=[dicReceipt[@"in_app"] firstObject];
        NSLog(@"购买成功:%@---%@",dicReceipt,dicInApp);
        //服务端处理，或者本地处理
    }else{
        NSLog(@"购买失败，未通过验证！");
    }
}

@end
