//
//  CJViewController.m
//  CJFileDownloader
//
//  Created by 练炽金 on 01/25/2019.
//  Copyright (c) 2019 练炽金. All rights reserved.
//

#import "CJViewController.h"
#import "CJFileDownloader.h"

@interface CJViewController ()
@property (nonatomic, weak) IBOutlet UILabel *label;
@property (nonatomic, weak) IBOutlet UIImageView *imageView;
@property (nonatomic, strong) NSURL *filePath1;
@property (nonatomic, strong) NSURL *filePath2;
@property (nonatomic, strong) NSURL *filePath3;
@property (nonatomic, copy) NSString *customCacheDirectory;
@property (nonatomic, copy) NSString *testUrl;
@end

@implementation CJViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory,NSUserDomainMask,YES);
    NSString *path = [paths objectAtIndex:0];
    path = [NSString stringWithFormat:@"%@/MyCache",path];
    self.customCacheDirectory = path;
	self.label.text = @"0%";
//    self.testUrl = @"https://www.typora.io/download/Typora.dmg";
    self.testUrl = @"https://ss2.baidu.com/6ONYsjip0QIZ8tyhnq/it/u=390685541,2567525653&fm=173&app=25&f=JPEG?w=600&h=450&s=FF301FC24D77328C0E39C89403008092";
    self.testUrl = @"";
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (IBAction)download222:(id)sender {
//    NSString *url = @"http://sz-stg4.yun.pingan.com:40080/userplatforms/rest/cloudFile/download/90";
    NSString *url = @"";
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
    NSString *path = [paths objectAtIndex:0];
    path = [NSString stringWithFormat:@"%@/测试机采购协议.docx",path];
    NSURL *URL = [NSURL URLWithString:url];
    [[CJFileDownloader manager]CJFileDownLoadWithUrl:URL parameters:nil cookies:@{@"hm_sessionid":@"e460be3b-8c3f-40dc-b260-877e5fb9d874"} cachePolicy:NSURLRequestReloadIgnoringLocalCacheData downloadFileCachePath:path progress:^(NSProgress *downloadProgress) {
        NSInteger fractionCompleted = downloadProgress.fractionCompleted * 100;
        self.label.text = [NSString stringWithFormat:@"下载%@%%",@(fractionCompleted)];
    } success:^(BOOL cache, NSURLResponse *response, NSURL *filePath, NSString *MIMEType) {
        
        long long cacheSzie = [[CJFileDownloader manager] fileSizeWithURL:URL customCachePath:self.customCacheDirectory];
        NSString *text = [NSString stringWithFormat:@"缓存大小：%.2fM",cacheSzie/(1024.0*1024.0)];
        self.label.text = [NSString stringWithFormat:@"完成度：100%%\n%@\n文件类型:%@",text,MIMEType];
        self.filePath2 = [NSURL fileURLWithPath:filePath.relativePath];
    } failure:^(NSInteger statusCode, NSError *error) {
        if (error.code != -999) {
            NSString *errorStr = error.localizedDescription;
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"下载失败" message:errorStr preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
            }]];
            [self presentViewController:alert animated:YES completion:nil];
        }
    }];
}

- (IBAction)download:(UIButton *)sender {
//    NSString *url = @"https://media.w3.org/2010/05/sintel/trailer.mp4";
//    NSString *url = @"https://www.typora.io/download/Typora.dmg";
    NSString *url = @"http://www.pptbz.com/pptpic/UploadFiles_6909/201306/2013062320262198.jpg";
    __block NSInteger tag = sender.tag;
    if (sender.tag == 2) {
        url = @"https://ss1.baidu.com/6ONXsjip0QIZ8tyhnq/it/u=1805641987,1290385220&fm=173&app=49&f=JPEG?w=640&h=360&s=62D05A8106B8BDC21E1C04810300E080";
    }else if (sender.tag == 3) {
//        url = @"https://ss2.baidu.com/6ONYsjip0QIZ8tyhnq/it/u=390685541,2567525653&fm=173&app=25&f=JPEG?w=600&h=450&s=FF301FC24D77328C0E39C89403008092";
//        url = @"http://sz-stg4.yun.pingan.com:40080/userplatforms/rest/file/download?url=/201903/12/c3b172ab99bf418baa44d8570d1e1694.PNG&uuid=62D05A8106B8BDC21E1C04810300E080";
        url = self.testUrl;
    }
    NSURL *URL = [NSURL URLWithString:url];
    [[CJFileDownloader manager]CJFileDownLoadWithUrl:URL parameters:nil cookies:@{@"hm_sessionid":@"755e6d06-fb89-44e4-99e2-f2cbfeab678c"} cachePolicy:NSURLRequestReloadIgnoringCacheData customCachePath:nil taskIdentifier:nil progress:^(id taskIdentifier, NSProgress *downloadProgress) {
        NSInteger fractionCompleted = downloadProgress.fractionCompleted * 100;
        self.label.text = [NSString stringWithFormat:@"下载%@%%",@(fractionCompleted)];
    } success:^(id taskIdentifier, BOOL cache, NSURLResponse *response, NSURL *filePath, NSString *MIMEType) {
        long long cacheSzie = [[CJFileDownloader manager] fileSizeWithURL:URL customCachePath:self.customCacheDirectory];
        NSString *text = [NSString stringWithFormat:@"缓存大小：%.2fM",cacheSzie/(1024.0*1024.0)];
        self.label.text = [NSString stringWithFormat:@"完成度：100%%\n%@\n文件类型:%@",text,MIMEType];
        switch (tag) {
            case 1:
                self.filePath1 = [NSURL fileURLWithPath:filePath.relativePath];
                break;
            case 2:
                self.filePath2 = [NSURL fileURLWithPath:filePath.relativePath];
                break;
            case 3:
                self.filePath3 = [NSURL fileURLWithPath:filePath.relativePath];
                break;
            default:
                break;
        }
        
        NSData *fileData = [NSData dataWithContentsOfURL:filePath options:NSDataReadingMappedIfSafe error:nil];
        UIImage *image = [UIImage imageWithData:fileData];
        self.imageView.image = image;
        
    } failure:^(id taskIdentifier, NSInteger statusCode, NSError *error) {
        if (error.code != -999) {
            NSString *errorStr = error.localizedDescription;
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"下载失败" message:errorStr preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
            }]];
            [self presentViewController:alert animated:YES completion:nil];
        }
    }];
}

- (IBAction)clearCache:(id)sender {
    [[CJFileDownloader manager]stopAllTasks];
    NSURL *url = [NSURL URLWithString:self.testUrl];
    long long size1 = [[CJFileDownloader manager]fileSizeWithURL:url customCachePath:self.customCacheDirectory];
    __block NSString *str = [NSString stringWithFormat:@"指定url 缓存大小 %.2fM",size1/(1024.0*1024.0)];
    [[CJFileDownloader manager]clearCacheWithUrl:url customCachePath:self.customCacheDirectory resultBlock:^(NSError *error, NSString *msg) {
        if (error) {
            NSString *errorStr = error.localizedDescription;
            str = [NSString stringWithFormat:@"%@_清除缓存失败",str];
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:str message:errorStr preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
            }]];
            [self presentViewController:alert animated:YES completion:nil];
        }else{
            NSString *str = [NSString stringWithFormat:@"%@_清除缓存成功",msg];
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:str message:str preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
            }]];
            [self presentViewController:alert animated:YES completion:nil];
        }
    }];
    self.label.text = @"0%";
    self.imageView.image = nil;
}

- (IBAction)clearAllCustomCache:(id)sender {
    long long size = [[CJFileDownloader manager]cacheSizeWithCustomCachePath:self.customCacheDirectory];
    __block NSString *str = [NSString stringWithFormat:@"自定义缓存大小 %.2fM",size/(1024.0*1024.0)];
    [[CJFileDownloader manager]clearCacheAtCustomCachePath:self.customCacheDirectory resultBlock:^(NSError *error, NSString *msg) {
        if (error) {
            NSString *errorStr = error.localizedDescription;
            str = [NSString stringWithFormat:@"%@_清除缓存失败",str];
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:str message:errorStr preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
            }]];
            [self presentViewController:alert animated:YES completion:nil];
        }else{
            NSString *str = [NSString stringWithFormat:@"%@_清除缓存成功",msg];
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:str message:str preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
            }]];
            [self presentViewController:alert animated:YES completion:nil];
        }
    }];
}

- (IBAction)clearAllCache:(id)sender {
//    [[CJFileDownloader manager]stopAllTasks];
    long long size = [[CJFileDownloader manager]cacheSizeWithCustomCachePath:nil];
    __block NSString *str = [NSString stringWithFormat:@"默认缓存大小 %.2fM",size/(1024.0*1024.0)];
    [[CJFileDownloader manager]clearCacheAtCustomCachePath:nil resultBlock:^(NSError *error, NSString *msg) {
        if (error) {
            NSString *errorStr = error.localizedDescription;
            str = [NSString stringWithFormat:@"%@_清除默认缓存失败",str];
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:str message:errorStr preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
            }]];
            [self presentViewController:alert animated:YES completion:nil];
        }else{
            NSString *errorStr = error.localizedDescription;
            str = [NSString stringWithFormat:@"%@_清除默认缓存成功",str];
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:str message:errorStr preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
            }]];
            [self presentViewController:alert animated:YES completion:nil];
        }
    }];
}

- (IBAction)uploadImage:(id)sender {
    if (!self.filePath1) {
        return;
    }
    NSString *url = @"";
    NSString *session = @"b3c0259e-d820-46f9-ab7e-f339a12acbc1";
    NSDictionary *param = @{@"loginsession": session,
                            @"sourcesys": @"4001",
                            @"v": @"1",
                            @"username": @"30100000001050351",
                            @"userSystem": @"0"
                            };
    NSDictionary *cookies = @{@"hm_sessionid":session,
                              @"jd_sessionid":session
                              };
    
    [[CJFileDownloader manager] uploadTaskWithUrl:url parameters:param cookies:cookies name:nil fromFile:self.filePath1 progress:^(NSProgress *uploadProgress) {
        NSInteger fractionCompleted = uploadProgress.fractionCompleted * 100;
        NSLog(@"上传进度 %@%%",@(fractionCompleted));
        self.label.text = [NSString stringWithFormat:@"上传%@%%",@(fractionCompleted)];
    } success:^(NSURLResponse *response, id responseObject) {
        NSLog(@"上传成功 %@",responseObject);
        self.label.text = @"上传成功";
    } failure:^(NSInteger statusCode, NSError *error) {
        NSString *errorStr = error.localizedDescription;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"文件1上传失败" message:errorStr preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        }]];
        [self presentViewController:alert animated:YES completion:nil];
    }];
}

- (IBAction)uploadImages:(id)sender {
    
    NSString *url = @"";
    NSString *session = @"b3c0259e-d820-46f9-ab7e-f339a12acbc1";
    NSDictionary *param = @{@"loginsession": session,
                            @"sourcesys": @"4001",
                            @"v": @"1",
                            @"username": @"30100000001050351",
                            @"userSystem": @"0"
                            };
    NSDictionary *cookies = @{@"hm_sessionid":session,
                              @"jd_sessionid":session
                              };
    NSMutableArray *array = [NSMutableArray array];
    if (self.filePath1) {
        [array addObject:self.filePath1];
    }
    if (self.filePath2) {
        [array addObject:self.filePath2];
    }
    if (self.filePath3) {
        [array addObject:self.filePath3];
    }
    [[CJFileDownloader manager] uploadTaskWithUrl:url parameters:param cookies:cookies name:nil fromFileList:array progress:^(NSURL *fileURL, NSProgress *uploadProgress) {
        NSInteger fractionCompleted = uploadProgress.fractionCompleted * 100;
        NSString *str = [self fileStr:fileURL];
        NSLog(@"%@，上传进度 %@%%",fileURL,@(fractionCompleted));
        self.label.text = [NSString stringWithFormat:@"%@，上传%@%%",str,@(fractionCompleted)];
    } success:^(NSURL *fileURL, NSURLResponse *response, id responseObject) {
        NSString *str = [self fileStr:fileURL];
        NSLog(@"%@，上传成功 %@",fileURL,responseObject);
        
        NSString *text = self.label.text;
        if ([text rangeOfString:@"上传成功"].location != NSNotFound) {
            self.label.text = [NSString stringWithFormat:@"%@；%@，上传成功",text,str];
        }else{
            self.label.text = [NSString stringWithFormat:@"%@，上传成功",str];
        }
    } failure:^(NSURL *fileURL, NSInteger statusCode, NSError *error) {
        NSString *errorStr = error.localizedDescription;
        NSLog(@"%@，上传失败 %@",fileURL,errorStr);
        NSString *str = [self fileStr:fileURL];
        NSString *title = [NSString stringWithFormat:@"%@，上传失败",str];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:errorStr preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        }]];
        [self presentViewController:alert animated:YES completion:nil];
    }];
}

- (NSString *)fileStr:(NSURL *)fileURL {
    NSString *str = @"";
    if ([[fileURL absoluteString]isEqualToString:[self.filePath1 absoluteString]]) {
        str = @"文件1";
    }else if ([[fileURL absoluteString]isEqualToString:[self.filePath2 absoluteString]]) {
        str = @"文件2";
    }else if ([[fileURL absoluteString]isEqualToString:[self.filePath3 absoluteString]]) {
        str = @"文件3";
    }
    return str;
}

@end
