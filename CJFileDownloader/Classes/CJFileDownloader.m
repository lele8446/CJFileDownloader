//
//  CJFileDownloader.m
//  CJFileDownloader
//
//  Created by 练炽金 on 2019/1/22.
//

#import "CJFileDownloader.h"
#import <CommonCrypto/CommonCrypto.h>

#if (!defined(DEBUG))
#define NSLog(...)
#endif

@interface CJFileDownloader ()
@property (nonatomic, strong) AFHTTPSessionManager *managerDownload;
@property (nonatomic, strong) AFHTTPSessionManager *managerUpload;
/**  下载历史记录 */
@property (nonatomic, strong) NSMutableDictionary *downLoadHistoryDictionary;
@property (nonatomic, copy) NSString *fileHistoryPath;
/** 用户主目录 */
@property (nonatomic, copy) NSString *homeDirectory;
@end

@implementation CJFileDownloader
//默认缓存路径 NSCachesDirectory + CJFileDownLoad
static inline NSString *CJFileDownLoadFileName() {
    static NSString *path = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory,NSUserDomainMask,YES);
        path = [paths objectAtIndex:0];
        path = [NSString stringWithFormat:@"%@/CJFileDownloader",path];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSError *error;
        [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error];
    });
    return path;
}

static inline NSString *CJFileDownLoadCachePath(NSString *customCachePath, NSString *host,NSString *key){
    NSString *path = nil;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (customCachePath.length > 0) {
        path = customCachePath;
        [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }else{
        path = CJFileDownLoadFileName();
    }
    
    if (host.length > 0) {
        NSString *hostPath = [NSString stringWithFormat:@"%@/%@",path,host];
        BOOL isDir = NO;
        BOOL isDirExist = [fileManager fileExistsAtPath:hostPath isDirectory:&isDir];
        if (!(isDirExist && isDir)) {
            [fileManager createDirectoryAtPath:hostPath withIntermediateDirectories:YES attributes:nil error:nil];
        }
    }
    
    if (host.length > 0) {
        path = [NSString stringWithFormat:@"%@/%@",path,host];
    }
    if (key.length > 0) {
        path = [NSString stringWithFormat:@"%@/%@",path,key];
    }
    BOOL isDir = FALSE;
    BOOL isDirExist = [fileManager fileExistsAtPath:path isDirectory:&isDir];
    if (!(isDirExist && isDir)) {
        [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return path;
}

/** 判断主线程block */
static inline void CJFileDownMainQueueAction(void(^block)(void)) {
    if ([NSThread isMainThread]) {
        block();
    }else{
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter]removeObserver:self];
}

+ (instancetype)manager {
    static CJFileDownloader *share = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        share = [[CJFileDownloader alloc] init];
    });
    return share;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.homeDirectory = NSHomeDirectory();
                
        //网络变化的通知
        //        [[NSNotificationCenter defaultCenter] addObserver:self
        //                                                 selector:@selector(networkChanged:)
        //                                                     name:kRealReachabilityChangedNotification
        //                                                   object:nil];
        
        NSURLSessionDownloadTask *task;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(downLoadData:)
                                                     name:AFNetworkingTaskDidCompleteNotification
                                                   object:task];
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory,NSUserDomainMask,YES);
        NSString *path = [paths objectAtIndex:0];
        self.fileHistoryPath = [path stringByAppendingPathComponent:@"fileDownLoadHistory.plist"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:self.fileHistoryPath]) {
            self.downLoadHistoryDictionary = [NSMutableDictionary dictionaryWithContentsOfFile:self.fileHistoryPath];
        }else{
            self.downLoadHistoryDictionary = [NSMutableDictionary dictionary];
            //将dictionary中的数据写入plist文件中
            [self.downLoadHistoryDictionary writeToFile:self.fileHistoryPath atomically:YES];
        }
    }
    return  self;
}
- (AFHTTPSessionManager *)managerDownload {
    if (!_managerDownload) {
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
            configuration.HTTPMaximumConnectionsPerHost = 10;
            
        //设置请求超时为60秒钟
//        configuration.timeoutIntervalForRequest = 60;//默认就是60s
//        configuration.timeoutIntervalForResource = 60;//数据没有在指定的时间里面加载完，默认值是7天
        //在蜂窝网络情况下是否继续请求（上传或下载）
        configuration.allowsCellularAccess = YES;
        configuration.discretionary = YES;
        
        _managerDownload = [[AFHTTPSessionManager alloc] initWithSessionConfiguration:configuration];
    }
    return _managerDownload;
}
- (void)customManagerDownload:(AFHTTPSessionManager *)managerDownload {
//    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"com.pingan.CJFileDownLoad"];//不能上传
//    configuration.HTTPMaximumConnectionsPerHost = 10;
//
//    //在蜂窝网络情况下是否继续请求（上传或下载）
//    configuration.allowsCellularAccess = YES;
//    configuration.discretionary = YES;
//    managerDownload = [[AFHTTPSessionManager alloc] initWithSessionConfiguration:configuration];
    
    self.managerDownload = managerDownload;
}
- (AFHTTPSessionManager *)managerUpload {
    if (!_managerUpload) {
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        configuration.HTTPMaximumConnectionsPerHost = 10;
        
        //在蜂窝网络情况下是否继续请求（上传或下载）
        configuration.allowsCellularAccess = YES;
        configuration.discretionary = YES;
        _managerUpload = [[AFHTTPSessionManager alloc] initWithSessionConfiguration:configuration];
    }
    return _managerUpload;
}
- (void)customManagerUpload:(AFHTTPSessionManager *)managerUpload {
    self.managerUpload = managerUpload;
}

- (void)saveHistoryWithKey:(NSString *)key DownloadTaskResumeData:(NSData *)data {
    if (!data) {
        NSString *emptyData = [NSString stringWithFormat:@""];
        [self.downLoadHistoryDictionary setObject:emptyData forKey:key];
        
    }else{
        [self.downLoadHistoryDictionary setObject:data forKey:key];
    }
    
    [self.downLoadHistoryDictionary writeToFile:self.fileHistoryPath atomically:NO];
}

- (void)saveDownLoadHistoryDirectory {
    [self.downLoadHistoryDictionary writeToFile:self.fileHistoryPath atomically:YES];
}

/** 是否有效的路径 */
- (BOOL)isValidPath:(NSString *)path {
    return ([path rangeOfString:self.homeDirectory].location != NSNotFound);
}

/* 获取到的路径为：
 * (NSCachesDirectory目录 + CJFileDownLoad) (或者是自定义缓存文件夹)/ 当前请求URL的host / 请求url地址MD5 / response.suggestedFilename
 */
- (NSString *)searchFilePathAtCustomCache:(NSString *)customCachePath fileKey:(NSString *)fileKey host:(NSString *)host {
    @autoreleasepool {
        NSString *resultFilePath = nil;
        NSFileManager* fileMgr = [NSFileManager defaultManager];
        //获取到 host 一级的路径
        NSString *path = CJFileDownLoadCachePath(customCachePath,host,nil);
        NSArray *tempArray = [fileMgr contentsOfDirectoryAtPath:path error:nil];
        for (NSString* fileName in tempArray) {
            //匹配到与 请求url地址MD5 同名的路径
            if ([fileName rangeOfString:fileKey].location != NSNotFound) {
                NSString *resultFileName = [path stringByAppendingPathComponent:fileName];
                NSFileManager *fileManager = [NSFileManager defaultManager];
                BOOL isDir = NO;
                BOOL isDirExist = [fileManager fileExistsAtPath:resultFileName isDirectory:&isDir];
                if (isDirExist && isDir) {
                    //取该路径下的文件（这个路径下只有有一个文件 response.suggestedFilename）
                    NSArray *tempArray = [fileManager contentsOfDirectoryAtPath:resultFileName error:nil];
                    if (tempArray.count > 0) {
                        resultFileName = [resultFileName stringByAppendingPathComponent:tempArray[0]];
                        resultFilePath = resultFileName;
                    }
                }
                break;
            }
        }
        return resultFilePath;
    }
}

- (NSURLSessionDownloadTask *)CJFileDownLoadWithUrl:(NSURL *)url
                                            progress:(void (^)(NSProgress *downloadProgress)) downloadProgressBlock
                                             success:(void (^)(BOOL cache,             /** 返回的是否为缓存数据，YES是缓存，此时的response为nil */
                                                               NSURLResponse *response /** 下载成功response */,
                                                               NSURL *filePath         /** 缓存路径 */,
                                                               NSString *MIMEType      /** 文件类型 */))success
                                             failure:(void (^)(NSInteger statusCode, NSError *error))failure {
    return [self CJFileDownLoadWithUrl:url cachePolicy:NSURLRequestUseProtocolCachePolicy taskIdentifier:nil progress:^(id taskIdentifier, NSProgress *downloadProgress) {
        if (downloadProgressBlock) {
            downloadProgressBlock(downloadProgress);
        }
    } success:^(id taskIdentifier, BOOL cache, NSURLResponse *response, NSURL *filePath, NSString *MIMEType) {
        if (success) {
            success(cache,response,filePath,MIMEType);
        }
    } failure:^(id taskIdentifier, NSInteger statusCode, NSError *error) {
        if (failure) {
            failure(statusCode,error);
        }
    }];
}

- (NSURLSessionDownloadTask *)CJFileDownLoadWithUrl:(NSURL *)url
                                         cachePolicy:(NSURLRequestCachePolicy)cachePolicy
                                      taskIdentifier:(id)taskIdentifier
                                            progress:(void (^)(id taskIdentifier, NSProgress *downloadProgress))downloadProgressBlock
                                             success:(void (^)(id taskIdentifier, BOOL cache, NSURLResponse *response, NSURL *filePath, NSString *MIMEType))success
                                             failure:(void (^)(id taskIdentifier, NSInteger statusCode, NSError *error))failure
{
    return [self CJFileDownLoadWithUrl:url parameters:nil cookies:nil cachePolicy:cachePolicy customCachePath:nil taskIdentifier:taskIdentifier progress:downloadProgressBlock success:success failure:failure];
}

- (NSURLSessionDownloadTask *)CJFileDownLoadWithUrl:(NSURL *)url
                                          parameters:(id)parameters
                                             cookies:(NSDictionary <NSString*, NSString*>*)cookies
                                         cachePolicy:(NSURLRequestCachePolicy)cachePolicy
                                     customCachePath:(NSString *)customCachePath
                                      taskIdentifier:(id)taskIdentifier
                                            progress:(void (^)(id taskIdentifier, NSProgress *downloadProgress)) downloadProgressBlock
                                             success:(void (^)(id taskIdentifier       /** 当前任务标识 */,
                                                               BOOL cache,             /** 返回的是否为缓存数据，YES是缓存，此时的response为nil */
                                                               NSURLResponse *response /** 下载成功response */,
                                                               NSURL *filePath         /** 缓存路径 */,
                                                               NSString *MIMEType      /** 文件类型 */))success
                                             failure:(void (^)(id taskIdentifier, NSInteger statusCode, NSError *error))failure
{
    if (customCachePath.length > 0 &&![self isValidPath:customCachePath]) {
        NSString *errorStr = [NSString stringWithFormat:@"无效的缓存路径，缓存路径 = %@",customCachePath];
        NSAssert([self isValidPath:customCachePath],errorStr);
        if (failure) {
            NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:CJFileDownloadTaskErrorCode userInfo:@{NSLocalizedDescriptionKey:errorStr}];
            failure(taskIdentifier,CJFileDownloadTaskErrorCode,error);
        }
        return nil;
    }
    __weak typeof(taskIdentifier)wTaskIdentifier = taskIdentifier;
    NSString *host = url.host;
    //缓存文件路径规则：(NSCachesDirectory目录 + CJFileDownLoad)（或者是自定义缓存文件夹）+ 当前请求URL的host + 请求url地址MD5 + response.suggestedFilename
    NSString *localFile = [self MD5Str:[url.absoluteString stringByRemovingPercentEncoding]];
    NSString *localFilePathStr = [self searchFilePathAtCustomCache:customCachePath fileKey:localFile host:host];
    NSURL *localFilePath = nil;
    if (localFilePathStr.length > 0) {
        localFilePath = [NSURL fileURLWithPath:localFilePathStr];
    }
    
    //默认缓存，先判断本地缓存，无缓存则取网络数据
    if (cachePolicy == NSURLRequestUseProtocolCachePolicy) {
        if (localFilePath) {
            if (success) {
                success(wTaskIdentifier,YES,nil,localFilePath,localFilePathStr.pathExtension);
            }
            return nil;
        }else{
            return [self downLoadWithUrl:url localFileName:localFile host:host parameters:parameters cookies:cookies customCachePath:customCachePath cachePolicy:cachePolicy taskIdentifier:wTaskIdentifier progress:downloadProgressBlock success:success failure:failure downloadFileCachePath:nil];
        }
    }
    //先判断本地缓存，再返回网络数据（可能会回调两次）
    else if (cachePolicy == NSURLRequestReturnCacheDataElseLoad || cachePolicy == NSURLRequestReloadRevalidatingCacheData) {
        if (localFilePath && success) {
            success(wTaskIdentifier,YES,nil,localFilePath,localFilePathStr.pathExtension);
        }
        return [self downLoadWithUrl:url localFileName:localFile host:host parameters:parameters cookies:cookies customCachePath:customCachePath cachePolicy:cachePolicy taskIdentifier:wTaskIdentifier progress:downloadProgressBlock success:success failure:failure downloadFileCachePath:nil];
    }
    //忽略缓存，只取网络
    else if (cachePolicy == NSURLRequestReloadIgnoringLocalCacheData || cachePolicy == NSURLRequestReloadIgnoringLocalAndRemoteCacheData || cachePolicy == NSURLRequestReloadIgnoringCacheData) {
        return [self downLoadWithUrl:url localFileName:localFile host:host parameters:parameters cookies:cookies customCachePath:customCachePath cachePolicy:cachePolicy taskIdentifier:wTaskIdentifier progress:downloadProgressBlock success:success failure:failure downloadFileCachePath:nil];
    }
    //只取缓存，离线模式
    else if (cachePolicy == NSURLRequestReturnCacheDataDontLoad) {
        if (localFilePath) {
            if (success) {
                success(wTaskIdentifier,YES,nil,localFilePath,localFilePathStr.pathExtension);
            }
        }else{
            if (failure) {
                NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:CJFileDownloadTaskErrorCode userInfo:@{NSLocalizedDescriptionKey:@"缓存不存在"}];
                failure(wTaskIdentifier,CJFileDownloadTaskErrorCode,error);
            }
        }
        return nil;
    }else{
        return nil;
    }
}

- (NSURLSessionDownloadTask *)CJFileDownLoadWithUrl:(NSURL *)url
                                          parameters:(id)parameters
                                             cookies:(NSDictionary <NSString*, NSString*>*)cookies
                                         cachePolicy:(NSURLRequestCachePolicy)cachePolicy
                               downloadFileCachePath:(NSString *)downloadFileCachePath
                                            progress:(void (^)(NSProgress *downloadProgress)) downloadProgressBlock
                                             success:(void (^)(BOOL cache,             /** 返回的是否为缓存数据，YES是缓存，此时的response为nil */
                                                               NSURLResponse *response /** 下载成功response */,
                                                               NSURL *filePath         /** 缓存路径 */,
                                                               NSString *MIMEType      /** 文件类型 */))success
                                             failure:(void (^)(NSInteger statusCode, NSError *error))failure
{
    if (downloadFileCachePath.length > 0 &&![self isValidPath:downloadFileCachePath]) {
        NSString *errorStr = [NSString stringWithFormat:@"无效的缓存路径，缓存路径 = %@",downloadFileCachePath];
        NSAssert([self isValidPath:downloadFileCachePath],errorStr);
        if (failure) {
            NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:CJFileDownloadTaskErrorCode userInfo:@{NSLocalizedDescriptionKey:errorStr}];
            failure(CJFileDownloadTaskErrorCode,error);
        }
        return nil;
    }

    NSURL *localFilePath = [NSURL fileURLWithPath:downloadFileCachePath];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL haveFile = [fileManager fileExistsAtPath:downloadFileCachePath];
    
    //默认缓存，先判断本地缓存，无缓存则取网络数据
    if (cachePolicy == NSURLRequestUseProtocolCachePolicy) {
        if (haveFile) {
            if (success) {
                success(YES,nil,localFilePath,downloadFileCachePath.pathExtension);
            }
            return nil;
        }else{
            return [self downLoadWithUrl:url localFileName:nil host:nil parameters:parameters cookies:cookies customCachePath:nil cachePolicy:cachePolicy taskIdentifier:nil progress:^(id taskIdentifier, NSProgress *downloadProgress) {
                if (downloadProgressBlock) {
                    downloadProgressBlock(downloadProgress);
                }
            } success:^(id taskIdentifier, BOOL cache, NSURLResponse *response, NSURL *filePath, NSString *MIMEType) {
                if (success) {
                    success(cache,response,filePath,MIMEType);
                }
            } failure:^(id taskIdentifier, NSInteger statusCode, NSError *error) {
                if (failure) {
                    failure(statusCode,error);
                }
            } downloadFileCachePath:downloadFileCachePath];
        }
    }
    //先判断本地缓存，再返回网络数据（可能会回调两次）
    else if (cachePolicy == NSURLRequestReturnCacheDataElseLoad || cachePolicy == NSURLRequestReloadRevalidatingCacheData) {
        if (haveFile && success) {
            success(YES,nil,localFilePath,downloadFileCachePath.pathExtension);
        }
        return [self downLoadWithUrl:url localFileName:nil host:nil parameters:parameters cookies:cookies customCachePath:nil cachePolicy:cachePolicy taskIdentifier:nil progress:^(id taskIdentifier, NSProgress *downloadProgress) {
            if (downloadProgressBlock) {
                downloadProgressBlock(downloadProgress);
            }
        } success:^(id taskIdentifier, BOOL cache, NSURLResponse *response, NSURL *filePath, NSString *MIMEType) {
            if (success) {
                success(cache,response,filePath,MIMEType);
            }
        } failure:^(id taskIdentifier, NSInteger statusCode, NSError *error) {
            if (failure) {
                failure(statusCode,error);
            }
        } downloadFileCachePath:downloadFileCachePath];
    }
    //忽略缓存，只取网络
    else if (cachePolicy == NSURLRequestReloadIgnoringLocalCacheData || cachePolicy == NSURLRequestReloadIgnoringLocalAndRemoteCacheData || cachePolicy == NSURLRequestReloadIgnoringCacheData) {
        return [self downLoadWithUrl:url localFileName:nil host:nil parameters:parameters cookies:cookies customCachePath:nil cachePolicy:cachePolicy taskIdentifier:nil progress:^(id taskIdentifier, NSProgress *downloadProgress) {
            if (downloadProgressBlock) {
                downloadProgressBlock(downloadProgress);
            }
        } success:^(id taskIdentifier, BOOL cache, NSURLResponse *response, NSURL *filePath, NSString *MIMEType) {
            if (success) {
                success(cache,response,filePath,MIMEType);
            }
        } failure:^(id taskIdentifier, NSInteger statusCode, NSError *error) {
            if (failure) {
                failure(statusCode,error);
            }
        } downloadFileCachePath:downloadFileCachePath];
    }
    //只取缓存，离线模式
    else if (cachePolicy == NSURLRequestReturnCacheDataDontLoad) {
        if (haveFile) {
            if (success) {
                success(YES,nil,localFilePath,downloadFileCachePath.pathExtension);
            }
        }else{
            if (failure) {
                NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:CJFileDownloadTaskErrorCode userInfo:@{NSLocalizedDescriptionKey:@"缓存不存在"}];
                failure(CJFileDownloadTaskErrorCode,error);
            }
        }
        return nil;
    }else{
        return nil;
    }
}

- (NSURLSessionDownloadTask *)downLoadWithUrl:(NSURL *)url
                                localFileName:(NSString *)localFileName
                                         host:(NSString *)host
                                   parameters:(id)parameters
                                      cookies:(NSDictionary <NSString*, NSString*>*)cookies
                              customCachePath:(NSString *)customCachePath
                                  cachePolicy:(NSURLRequestCachePolicy)cachePolicy
                               taskIdentifier:(id)taskIdentifier
                                     progress:(void (^)(id taskIdentifier, NSProgress *downloadProgress)) downloadProgressBlock
                                      success:(void (^)(id taskIdentifier, BOOL cache, NSURLResponse *response, NSURL *filePath, NSString *MIMEType))success
                                      failure:(void (^)(id taskIdentifier, NSInteger statusCode, NSError *error))failure
                        downloadFileCachePath:(NSString *)downloadFileCachePath
{
    
    NSError *error = nil;
    NSMutableURLRequest *request = [self.managerDownload.requestSerializer requestWithMethod:@"GET" URLString:url.absoluteString parameters:parameters error:&error];
    if (error) {
        if (failure) {
            CJFileDownMainQueueAction(^{
                if (failure) {
                    failure(taskIdentifier,CJFileDownloadTaskErrorCode,error);
                }
            });
        }
        return nil;
    }
    request = [self request:request setCookie:cookies];
    request.cachePolicy = cachePolicy;
    NSURLSessionDownloadTask *downloadTask = nil;
    NSData *downLoadHistoryData = [self.downLoadHistoryDictionary objectForKey:url.absoluteString];
    //断点下载
    if (downLoadHistoryData.length > 0 ) {
        downloadTask = [self.managerDownload downloadTaskWithResumeData:downLoadHistoryData progress:^(NSProgress * _Nonnull downloadProgress) {
            CJFileDownMainQueueAction(^{
                if (downloadProgressBlock) {
                    downloadProgressBlock(taskIdentifier,downloadProgress);
                }
            });
        } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
            if (downloadFileCachePath.length > 0) {
                return [NSURL fileURLWithPath:downloadFileCachePath];
            }else{
                //缓存文件路径规则：(NSCachesDirectory目录 + CJFileDownLoad)（或者是自定义缓存文件夹）+ 当前请求URL的host + 请求url地址MD5 + response.suggestedFilename
                NSString *suggestedFilename = response.suggestedFilename;
                suggestedFilename = [suggestedFilename stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                NSString *path = CJFileDownLoadCachePath(customCachePath,host,localFileName);
                path = [NSString stringWithFormat:@"%@/%@",path,suggestedFilename];
                return [NSURL fileURLWithPath:path];
            }
        } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
            if ([httpResponse statusCode] == 404) {
                [[NSFileManager defaultManager] removeItemAtURL:filePath error:nil];
            }
            if (error) {
                CJFileDownMainQueueAction(^{
                    if (failure) {
                        failure(taskIdentifier,[httpResponse statusCode],error);
                    }
                });
            }else{
                [@" " stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                NSString *MIMEType = [filePath.absoluteString stringByRemovingPercentEncoding].pathExtension;
                BOOL isSuccess = YES;
                if (MIMEType.length == 0) {
                    isSuccess = NO;
                }
                if (isSuccess) {
                    CJFileDownMainQueueAction(^{
                        if (success) {
                            success(taskIdentifier,NO,response,filePath,MIMEType);
                        }
                    });
                }else{
                    CJFileDownMainQueueAction(^{
                        NSString *errorStr = [NSString stringWithFormat:@"文件下载完成解析出错！未知的文件格式：%@",MIMEType];
                        NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:CJFileDownloadTaskErrorCode userInfo:@{NSLocalizedDescriptionKey:errorStr}];
                        if (failure) {
                            failure(taskIdentifier,CJFileDownloadTaskErrorCode,error);
                        }
                        if (downloadFileCachePath.length > 0) {
                            //移除下载出错的文件缓存
                            [self clearCacheWithUrl:url customCachePath:customCachePath resultBlock:nil];
                        }else{
                            NSFileManager *fileManager = [NSFileManager defaultManager];
                            [fileManager removeItemAtPath:downloadFileCachePath error:nil];
                        }
                    });
                }
            }
        }];
    }else{
        //开辟 新任务
        downloadTask = [self.managerDownload downloadTaskWithRequest:request progress:^(NSProgress * _Nonnull downloadProgress) {
            NSLog(@"downloadProgress: %f", downloadProgress.fractionCompleted);
            CJFileDownMainQueueAction(^{
                if (downloadProgressBlock) {
                    downloadProgressBlock(taskIdentifier,downloadProgress);
                }
            });
        } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
            if (downloadFileCachePath.length > 0) {
                return [NSURL fileURLWithPath:downloadFileCachePath];
            }else{
                //缓存文件路径规则：(NSCachesDirectory目录 + CJFileDownLoad)（或者是自定义缓存文件夹）+ 当前请求URL的host + 请求url地址MD5 + response.suggestedFilename
                NSString *suggestedFilename = response.suggestedFilename;
                suggestedFilename = [suggestedFilename stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                NSString *path = CJFileDownLoadCachePath(customCachePath,host,localFileName);
                path = [NSString stringWithFormat:@"%@/%@",path,suggestedFilename];
                return [NSURL fileURLWithPath:path];
            }
            
        } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
            if ([httpResponse statusCode] == 404) {
                [[NSFileManager defaultManager] removeItemAtURL:filePath error:nil];
            }
            if (error) {
                CJFileDownMainQueueAction(^{
                    if (failure) {
                        failure(taskIdentifier,[httpResponse statusCode],error);
                    }
                });
            }else{
                NSString *MIMEType = [filePath.absoluteString stringByRemovingPercentEncoding].pathExtension;
                BOOL isSuccess = YES;
                if (MIMEType.length == 0) {
                    isSuccess = NO;
                }
                if (isSuccess) {
                    CJFileDownMainQueueAction(^{
                        if (success) {
                            success(taskIdentifier,NO,response,filePath,MIMEType);
                        }
                    });
                }else{
                    CJFileDownMainQueueAction(^{
                        NSString *errorStr = [NSString stringWithFormat:@"文件下载完成解析出错！未知的文件格式：%@",MIMEType];
                        NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:CJFileDownloadTaskErrorCode userInfo:@{NSLocalizedDescriptionKey:errorStr}];
                        if (failure) {
                            failure(taskIdentifier,CJFileDownloadTaskErrorCode,error);
                        }
                        if (downloadFileCachePath.length > 0) {
                            //移除下载出错的文件缓存
                            [self clearCacheWithUrl:url customCachePath:customCachePath resultBlock:nil];
                        }else{
                            NSFileManager *fileManager = [NSFileManager defaultManager];
                            [fileManager removeItemAtPath:downloadFileCachePath error:nil];
                        }
                    });
                }
            }
        }];
    }
    [downloadTask resume];
    return downloadTask;
}

/***************************************下载模块的关键的代码 下载停止（完成、失败）会回调***************************************/
- (void)downLoadData:(NSNotification *)notification {
    
    if ([notification.object isKindOfClass:[NSURLSessionDownloadTask class]]) {
        NSURLSessionDownloadTask *task = notification.object;
        NSString *urlHost = [task.currentRequest.URL path];
        NSError *error = [notification.userInfo objectForKey:AFNetworkingTaskDidCompleteErrorKey] ;
        if (error) {
            if (error.code == -1001) {
                NSLog(@"CJFileDownloader：下载出错,看一下网络是否正常");
            }
            if (urlHost.length > 0) {
                NSData *resumeData = [error.userInfo objectForKey:@"NSURLSessionDownloadTaskResumeData"];
                //这个是因为 用户比如强退程序之后 ,再次进来的时候 存进去这个继续的data  需要用户去刷新列表
                [self saveHistoryWithKey:urlHost DownloadTaskResumeData:resumeData];
            }
        }else{
            if ([self.downLoadHistoryDictionary valueForKey:urlHost]) {
                [self.downLoadHistoryDictionary removeObjectForKey:urlHost];
                [self saveDownLoadHistoryDirectory];
            }
        }
    }
}
- (void)stopAllTasks {
    //停止所有的下载
    if ([[self.managerDownload downloadTasks] count]  > 0) {
        for (NSURLSessionDownloadTask *task in [self.managerDownload downloadTasks]) {
            if (task.state == NSURLSessionTaskStateRunning) {
                [task cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
                    
                }];
            }
        }
    }
    //停止所有上传
    if ([[self.managerUpload uploadTasks] count]  > 0) {
        for (NSURLSessionUploadTask *task in [self.managerUpload uploadTasks]) {
            if (task.state == NSURLSessionTaskStateRunning) {
                [task cancel];
            }
        }
    }
}

- (void)stopTasks:(NSURLSessionTask *)task {
    if ([task isKindOfClass:[NSURLSessionDownloadTask class]]) {
        if ([[self.managerDownload downloadTasks] count]  == 0) {
            return;
        }
        if (task.state == NSURLSessionTaskStateRunning) {
            [(NSURLSessionDownloadTask *)task cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
                
            }];
        }
    }
    else if ([task isKindOfClass:[NSURLSessionUploadTask class]]) {
        if ([[self.managerUpload uploadTasks] count]  == 0) {
            return;
        }
        if (task.state == NSURLSessionTaskStateRunning) {
            [task cancel];
        }
    }
}

- (BOOL)clearCacheAtCustomCachePath:(NSString *)customCachePath resultBlock:(void(^)(NSError *error, NSString *msg))resultBlock {
    
    if (customCachePath.length > 0 && ![self isValidPath:customCachePath]) {
        NSString *errorStr = [NSString stringWithFormat:@"无效的缓存路径，缓存路径 = %@",customCachePath];
        NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:CJClearCacheErrorCode userInfo:@{NSLocalizedDescriptionKey:errorStr}];
        if (resultBlock) {
            resultBlock(error,nil);
        }
        return NO;
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (customCachePath.length > 0) {
        
        BOOL isDir = NO;
        BOOL isDirExist = [fileManager fileExistsAtPath:customCachePath isDirectory:&isDir];
        if (!(isDirExist && isDir)) {
            NSString *msg = [NSString stringWithFormat:@"缓存不存在，缓存路径 = %@",customCachePath];
            if (resultBlock) {
                resultBlock(nil,msg);
            }
            return YES;
        }
    }
    
    BOOL result = YES;
    NSString *path = nil;
    NSError *error = nil;
    NSArray *tempArray = nil;
    if (customCachePath.length > 0) {
        path = customCachePath;
        tempArray = [fileManager contentsOfDirectoryAtPath:path error:&error];
    }else{
        path = CJFileDownLoadFileName();
        tempArray = [fileManager contentsOfDirectoryAtPath:path error:&error];
    }
    
    
    for (NSString *fileName in tempArray) {
        NSString *resultFileName = [path stringByAppendingPathComponent:fileName];
        result = [fileManager removeItemAtPath:resultFileName error:&error];
    }
    if (error) {
        if (resultBlock) {
            resultBlock(error,nil);
        }
        return NO;
    }
    if (customCachePath.length > 0) {
        [fileManager removeItemAtPath:path error:&error];
    }
    if (error) {
        if (resultBlock) {
            resultBlock(error,nil);
        }
        return NO;
    }
    self.downLoadHistoryDictionary = [NSMutableDictionary dictionary];
    //将dictionary中的数据写入plist文件中
    [self.downLoadHistoryDictionary writeToFile:self.fileHistoryPath atomically:YES];
    if (resultBlock) {
        resultBlock(nil,@"缓存清除成功");
    }
    return YES;
}

- (BOOL)clearCacheWithUrl:(NSURL *)url customCachePath:(NSString *)customCachePath resultBlock:(void(^)(NSError *error, NSString *msg))resultBlock {
    if (customCachePath.length > 0 &&![self isValidPath:customCachePath]) {
        NSString *errorStr = [NSString stringWithFormat:@"无效的缓存路径，缓存路径 = %@",customCachePath];
        NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:CJClearCacheErrorCode userInfo:@{NSLocalizedDescriptionKey:errorStr}];
        if (resultBlock) {
            resultBlock(error,nil);
        }
        return NO;
    }
    NSString *localFilePath = [self cacheFilePathWithUrl:url customCachePath:customCachePath];
    if (localFilePath) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSError *error;
        [fileManager removeItemAtPath:localFilePath error:&error];
        if (error) {
            if (resultBlock) {
                resultBlock(error,nil);
            }
            return NO;
        }
    }else{
        NSString *msg = [NSString stringWithFormat:@"缓存文件不存在，文件URL = %@",url];
        if (resultBlock) {
            resultBlock(nil,msg);
        }
        return YES;
    }
    if (resultBlock) {
        resultBlock(nil,@"缓存清除成功");
    }
    return YES;
}

- (BOOL)clearCacheAtFilePath:(NSString *)filePath resultBlock:(void(^)(NSError *error, NSString *msg))resultBlock {
    if (filePath.length > 0 &&![self isValidPath:filePath]) {
        NSString *errorStr = [NSString stringWithFormat:@"无效的缓存路径，缓存路径 = %@",filePath];
        NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:CJClearCacheErrorCode userInfo:@{NSLocalizedDescriptionKey:errorStr}];
        if (resultBlock) {
            resultBlock(error,nil);
        }
        return NO;
    }
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    [fileManager removeItemAtPath:filePath error:&error];
    if (error) {
        if (resultBlock) {
            resultBlock(error,nil);
        }
        return NO;
    }
    if (resultBlock) {
        resultBlock(nil,@"缓存清除成功");
    }
    return YES;
}

- (NSString *)cacheFilePathWithUrl:(NSURL *)url customCachePath:(NSString *)customCachePath {
    if (customCachePath.length > 0 &&![self isValidPath:customCachePath]) {
        NSString *errorStr = [NSString stringWithFormat:@"无效的缓存路径，缓存路径 = %@",customCachePath];
        NSLog(@"%@",errorStr);
        return @"";
    }
    NSString *host = url.host;
    NSString *localFile = [self MD5Str:[url.absoluteString stringByRemovingPercentEncoding]];
    NSString *localFilePath = [self searchFilePathAtCustomCache:customCachePath fileKey:localFile host:host];
    return localFilePath;
}

- (long long)cacheSizeWithFilePath:(NSString *)filePath {
    return [self fileSizeAtPath:filePath];
}

- (long long)fileSizeWithURL:(NSURL *)url customCachePath:(NSString *)customCachePath {
    if (customCachePath.length > 0 &&![self isValidPath:customCachePath]) {
        NSString *errorStr = [NSString stringWithFormat:@"无效的缓存路径，缓存路径 = %@",customCachePath];
        NSLog(@"%@",errorStr);
        return 0;
    }
    NSString *host = url.host;
    //缓存文件路径：(NSCachesDirectory目录 / CJFileDownLoad)（或者是自定义缓存文件夹）/ 当前请求URL的host / 请求url地址MD5 / response.suggestedFilename
    NSString *localFile = [self MD5Str:[url.absoluteString stringByRemovingPercentEncoding]];
    NSString *localFilePathStr = [self searchFilePathAtCustomCache:customCachePath fileKey:localFile host:host];
    return [self fileSizeAtPath:localFilePathStr];
}

- (long long)cacheSizeWithCustomCachePath:(NSString *)customCachePath {
    if (customCachePath.length > 0 &&![self isValidPath:customCachePath]) {
        NSString *errorStr = [NSString stringWithFormat:@"无效的缓存路径，缓存路径 = %@",customCachePath];
        NSLog(@"%@",errorStr);
        return 0;
    }
    NSFileManager* manager = [NSFileManager defaultManager];
    NSString *folderPath = nil;
    if (customCachePath.length > 0) {
        folderPath = customCachePath;
    }else{
        folderPath = CJFileDownLoadFileName();
    }
    if (![manager fileExistsAtPath:folderPath]) return 0;
    NSEnumerator *childFilesEnumerator = [[manager subpathsAtPath:folderPath] objectEnumerator];
    NSString* fileName;
    long long folderSize = 0;
    while ((fileName = [childFilesEnumerator nextObject]) != nil) {
        NSString* fileAbsolutePath = [folderPath stringByAppendingPathComponent:fileName];
        folderSize += [self fileSizeAtPath:fileAbsolutePath];
    }
    return folderSize;
}

- (long long)fileSizeAtPath:(NSString *)filePath {
    NSFileManager *manager = [NSFileManager defaultManager];
    if ([manager fileExistsAtPath:filePath]){
        return [[manager attributesOfItemAtPath:filePath error:nil] fileSize];
    }
    return 0;
}

- (NSMutableString *)MD5Str:(NSString *)str {
    const char *cStr = [str UTF8String];
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5( cStr, (unsigned int)str.length, digest );
    NSMutableString *result = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [result appendFormat:@"%02x", digest[i]];
    }
    return result;
}


#pragma mark - 上传
/**
 上传文件【二进制】

 @param url                 文件上传地址
 @param parameters          请求参数
 @param cookies             cookies
 @param fileName       文件名
 @param name                与上传数据关联的名称，需要与服务器约定，注意⚠️不是文件名（默认：file）
 @param fromData             文件的二进制
 @param uploadProgressBlock 上传进度
 @param success             上传成功回调
 @param failure             上传失败回调
 @return                    NSURLSessionDataTask
 */
- (NSURLSessionDataTask *)uploadTaskWithUrl:(NSString *)url
                                 parameters:(id)parameters
                                    cookies:(NSDictionary <NSString*, NSString*>*)cookies
                                   fileName:(NSString *)fileName
                                       name:(NSString *)name
                                   fromData:(NSData *)fromData
                                   progress:(void (^)(NSProgress *uploadProgress))uploadProgressBlock
                                    success:(void (^)(NSURLResponse *response, id responseObject))success
                                    failure:(void (^)(NSInteger statusCode, NSError *error))failure {

    
    NSError *error = nil;
    NSMutableURLRequest *request = [self.managerUpload.requestSerializer multipartFormRequestWithMethod:@"POST" URLString:url parameters:parameters constructingBodyWithBlock:nil error:&error];
    if (error) {
        if (failure) {
            failure(CJFileUploadTaskErrorCode,error);
        }
        return nil;
    }
    request = [self request:request setCookie:cookies];
    
    NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSArray<NSHTTPCookie *> *cookiess = storage.cookies;
    __block NSString *CJ_sessionid = @"";
    [cookiess enumerateObjectsUsingBlock:^(NSHTTPCookie * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.name isEqualToString:@"hm_sessionid"]) {
            CJ_sessionid = obj.value;
        }
    }];
    
    __block NSURLSessionDataTask *task =
    //流上传方式
    [self.managerUpload POST:url parameters:parameters headers:@{@"CJ-sessionid": CJ_sessionid} constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
        
        NSString *dataName = (name.length>0)?name:@"file";
        [formData appendPartWithFileData:fromData name:dataName fileName:fileName mimeType:[fileName pathExtension]];
        
    } progress:^(NSProgress * _Nonnull uploadProgress) {
        CJFileDownMainQueueAction(^{
            if (uploadProgressBlock) {
                uploadProgressBlock(uploadProgress);
            }
        });
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        CJFileDownMainQueueAction(^{
            if (success) {
                success(task.response,responseObject);
            }
        });
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {

        NSData *errData = error.userInfo[@"com.alamofire.serialization.response.error.data"];
        NSString *errStr = [[NSString alloc] initWithData:errData encoding:4];
        NSLog(@"request_err:%@",errStr);
        
        CJFileDownMainQueueAction(^{
            if (failure) {
                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)task.response;
                failure([httpResponse statusCode],error);
            }
        });
    }];
    [task resume];
    return task;
}
- (NSURLSessionDataTask *)uploadTaskWithUrl:(NSString *)url
                                 parameters:(id)parameters
                                    cookies:(NSDictionary <NSString*, NSString*>*)cookies
                                       name:(NSString *)name
                                   fromData:(NSData *)fromData
                                   progress:(void (^)(NSProgress *uploadProgress))uploadProgressBlock
                                    success:(void (^)(NSURLResponse *response, id responseObject))success
                                    failure:(void (^)(NSInteger statusCode, NSError *error))failure {
    NSURLSessionDataTask *task = [self uploadTaskWithUrl:url parameters:parameters cookies:cookies fileName:[url lastPathComponent] name:name fromData:fromData progress:uploadProgressBlock success:success failure:failure];
    return task;
}
- (NSURLSessionDataTask *)uploadTaskWithUrl:(NSString *)url
                                 parameters:(id)parameters
                                    cookies:(NSDictionary <NSString*, NSString*>*)cookies
                                       name:(NSString *)name
                                   fromFile:(NSURL *)fileURL
                                   progress:(void (^)(NSProgress *uploadProgress))uploadProgressBlock
                                    success:(void (^)(NSURLResponse *response, id responseObject))success
                                    failure:(void (^)(NSInteger statusCode, NSError *error))failure {
    
    NSError *error = nil;
    NSString *filePathStr = [fileURL.absoluteString stringByRemovingPercentEncoding];
    NSData *fileData = [NSData dataWithContentsOfURL:fileURL options:NSDataReadingMappedIfSafe error:&error];
    if (error) {
        if (failure) {
            failure(CJFileUploadTaskErrorCode,error);
        }
        return nil;
    }
    
    NSURLSessionDataTask *task = [self uploadTaskWithUrl:url parameters:parameters cookies:cookies fileName:[filePathStr lastPathComponent] name:name fromData:fileData progress:uploadProgressBlock success:success failure:failure];
    
//    NSMutableURLRequest *request = [self.manager.requestSerializer multipartFormRequestWithMethod:@"POST" URLString:url parameters:parameters constructingBodyWithBlock:nil error:&error];
//    if (error) {
//        if (failure) {
//            failure(CJFileUploadTaskErrorCode,error);
//        }
//        return nil;
//    }
//    request = [self request:request setCookie:cookies];
//
//    __block NSURLSessionDataTask *task =
//    //流上传方式
//    [self.manager POST:url parameters:parameters headers:nil constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
//
//        NSString *dataName = (name.length>0)?name:@"file";
//        [formData appendPartWithFileData:fileData name:dataName fileName:[filePathStr lastPathComponent] mimeType:[filePathStr pathExtension]];
//
//    } progress:^(NSProgress * _Nonnull uploadProgress) {
//        CJFileDownMainQueueAction(^{
//            if (uploadProgressBlock) {
//                uploadProgressBlock(uploadProgress);
//            }
//        });
//    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
//        CJFileDownMainQueueAction(^{
//            if (success) {
//                success(task.response,responseObject);
//            }
//        });
//    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
//        CJFileDownMainQueueAction(^{
//            if (failure) {
//                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)task.response;
//                failure([httpResponse statusCode],error);
//            }
//        });
//    }];
//    [task resume];
    return task;
}

- (void)uploadTaskWithUrl:(NSString *)url
               parameters:(id)parameters
                  cookies:(NSDictionary <NSString*, NSString*>*)cookies
                     name:(NSString *)name
             fromFileList:(NSArray <NSURL *>*)fileList
                 progress:(void (^)(NSURL *fileURL, NSProgress *uploadProgress))uploadProgressBlock
                  success:(void (^)(NSURL *fileURL, NSURLResponse *response, id responseObject))success
                  failure:(void (^)(NSURL *fileURL, NSInteger statusCode, NSError *error))failure {
    for (NSURL *fileURL in fileList) {
        [self uploadTaskWithUrl:url parameters:parameters cookies:cookies name:name fromFile:fileURL progress:^(NSProgress *uploadProgress) {
            if (uploadProgressBlock) {
                uploadProgressBlock(fileURL,uploadProgress);
            }
        } success:^(NSURLResponse *response, id responseObject) {
            if (success) {
                success(fileURL,response,responseObject);
            }
        } failure:^(NSInteger statusCode, NSError *error) {
            if (failure) {
                failure(fileURL,statusCode,error);
            }
        }];
    }
}


- (NSURLSessionUploadTask *)uploadTaskWithUrl:(NSString *)url
                                   parameters:(id)parameters
                                      cookies:(NSDictionary <NSString*, NSString*>*)cookies
                                     fromData:(NSData *)bodyData
                                     progress:(void (^)(NSProgress *uploadProgress))uploadProgressBlock
                                      success:(void (^)(NSURLResponse *response, id responseObject))success
                                      failure:(void (^)(NSInteger statusCode, NSError *error))failure {
    NSError *error = nil;
    NSMutableURLRequest *request = [self.managerUpload.requestSerializer multipartFormRequestWithMethod:@"POST" URLString:url parameters:parameters constructingBodyWithBlock:nil error:&error];
    if (error) {
        if (failure) {
            failure(CJFileUploadTaskErrorCode,error);
        }
        return nil;
    }
    request = [self request:request setCookie:cookies];
    NSURLSessionUploadTask *task =
    [self.managerUpload uploadTaskWithRequest:request fromData:bodyData progress:uploadProgressBlock completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
        if (error) {
            CJFileDownMainQueueAction(^{
                if (failure) {
                    failure([httpResponse statusCode],error);
                }
            });
        }else{
            CJFileDownMainQueueAction(^{
                if (success) {
                    success(response,responseObject);
                }
            });
        }
    }];
    [task resume];
    return task;
}


- (NSURLSessionUploadTask *)uploadTaskWithStreamedRequest:(NSMutableURLRequest *)request
                                                 progress:(void (^)(NSProgress *uploadProgress))uploadProgressBlock
                                                  success:(void (^)(NSURLResponse *response, id responseObject))success
                                                  failure:(void (^)(NSInteger statusCode, NSError *error))failure {
    NSURLSessionUploadTask *task =
    [self.managerUpload uploadTaskWithStreamedRequest:request progress:uploadProgressBlock completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
        if (error) {
            CJFileDownMainQueueAction(^{
                if (failure) {
                    failure([httpResponse statusCode],error);
                }
            });
        }else{
            CJFileDownMainQueueAction(^{
                if (success) {
                    success(response,responseObject);
                }
            });
        }
    }];
    [task resume];
    return task;
}

- (NSMutableURLRequest *)request:(NSMutableURLRequest *)request setCookie:(NSDictionary *)cookies {
    NSString *Cookie = nil;
    NSArray *allKeys = cookies.allKeys;
    for (NSInteger i = 0; i<allKeys.count; i++) {
        NSString *key = allKeys[i];
        if (i==allKeys.count-1) {
            Cookie = [NSString stringWithFormat:@"%@=%@",key,cookies[key]];
        }else{
            Cookie = [NSString stringWithFormat:@"%@=%@,",key,cookies[key]];
        }
    }
    if (Cookie.length > 0) {
        [request setValue:Cookie forHTTPHeaderField:@"Cookie"];
    }
    return request;
}
@end
