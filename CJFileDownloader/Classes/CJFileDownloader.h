//
//  CJFileDownloader.h
//  CJFileDownloader
//
//  Created by 练炽金 on 2019/1/22.
//

#import <Foundation/Foundation.h>
#import <AFNetworking/AFNetworking.h>

//自定义上传错误码
#define CJFileUploadTaskErrorCode     -77777
//自定义下载错误码
#define CJFileDownloadTaskErrorCode   -88888
//自定义删除缓存错误码
#define CJClearCacheErrorCode         -99999

/**
 CJFileDownloader 支持任意文件下载，支持断点下载，导出缓存路径
 */
@interface CJFileDownloader : NSObject
/** AFHTTPSessionManager 下载管理实例，需要自定义请使用 -customManagerDownload: 方法重写*/
@property (nonatomic, strong, readonly) AFHTTPSessionManager *managerDownload;
/** AFHTTPSessionManager 上传管理实例 需要自定义请使用 -customManagerUpload: 方法重写*/
@property (nonatomic, strong, readonly) AFHTTPSessionManager *managerUpload;

/** 获取单例 */
+ (instancetype)manager;

/// 自定义下载管理实例
/// @param managerDownload 自定义下载管理实例
- (void)customManagerDownload:(AFHTTPSessionManager *)managerDownload;

/// 自定义上传管理实例
/// @param managerUpload 自定义上传管理实例
- (void)customManagerUpload:(AFHTTPSessionManager *)managerUpload;

/** 取消所有下载、上传请求 */
- (void)stopAllTasks;

/** 取消指定网络请求 */
- (void)stopTasks:(NSURLSessionTask *)task;

/**
 清除指定文件夹下的缓存

 @param customCachePath      注意⚠️：只能是文件夹，不能具体到文件路径。自定义缓存文件夹路径（nil或者为空，取默认值：NSCachesDirectory 路径下的 CJFileDownLoad 文件夹）
 @param resultBlock          结果回调
 */
- (BOOL)clearCacheAtCustomCachePath:(NSString *)customCachePath resultBlock:(void(^)(NSError *error, NSString *msg))resultBlock;

/**
 清除指定文件夹下的指定文件的缓存

 @param url 指定文件的URL
 @param customCachePath      注意⚠️：只能是文件夹，不能具体到文件路径。自定义缓存路径（nil或者为空，取默认值：NSCachesDirectory 路径下的 CJFileDownLoad 文件夹）
 @param resultBlock          结果回调
 */
- (BOOL)clearCacheWithUrl:(NSURL *)url customCachePath:(NSString *)customCachePath resultBlock:(void(^)(NSError *error, NSString *msg))resultBlock;

/**
 清除指定文件的缓存
 
 @param filePath             文件缓存路径
 @param resultBlock          结果回调
 */
- (BOOL)clearCacheAtFilePath:(NSString *)filePath resultBlock:(void(^)(NSError *error, NSString *msg))resultBlock;

/**
  获取指定文件夹下指定文件的缓存路径

 @param url 指定文件的URL
 @param customCachePath 注意⚠️：只能是文件夹，不能具体到文件路径。自定义缓存路径（nil或者为空，取默认值：NSCachesDirectory 路径下的 CJFileDownLoad 文件夹）
 @return 缓存路径
 */
- (NSString *)cacheFilePathWithUrl:(NSURL *)url customCachePath:(NSString *)customCachePath;

/**
 获取指定文件夹下指定文件的缓存大小

 @param url 指定文件的URL
 @param customCachePath 注意⚠️：只能是文件夹，不能具体到文件路径。自定义缓存路径（nil或者为空，取默认值：NSCachesDirectory 路径下的 CJFileDownLoad 文件夹）
 @return 缓存大小
 */
- (long long)fileSizeWithURL:(NSURL *)url customCachePath:(NSString *)customCachePath;

/**
 获取指定文件夹下所有缓存的大小

 @param customCachePath 注意⚠️：只能是文件夹，不能具体到文件路径。自定义缓存路径（nil或者为空，取默认值：NSCachesDirectory 路径下的 CJFileDownLoad 文件夹）
 @return 缓存大小
 */
- (long long)cacheSizeWithCustomCachePath:(NSString *)customCachePath;

/**获取指定文件的缓存大小*/
- (long long)cacheSizeWithFilePath:(NSString *)filePath;

/**
 下载文件

 @param url                   下载文件地址
 @param downloadProgressBlock 下载进度回调
 @param success               下载成功回调
 @param failure               下载失败回调
 @return                      NSURLSessionDownloadTask
 */
- (NSURLSessionDownloadTask *)CJFileDownLoadWithUrl:(NSURL *)url
                                            progress:(void (^)(NSProgress *downloadProgress)) downloadProgressBlock
                                             success:(void (^)(BOOL cache,             /** 返回的是否为缓存数据，YES是缓存，此时的response为nil */
                                                               NSURLResponse *response /** 下载成功response */,
                                                               NSURL *filePath         /** 缓存路径 */,
                                                               NSString *MIMEType      /** 文件类型 */))success
                                             failure:(void (^)(NSInteger statusCode, NSError *error))failure;

/**
 下载文件，可自定义缓存策略，标识当前Task

 @param url         下载文件地址
 @param cachePolicy 缓存策略
        - NSURLRequestUseProtocolCachePolicy 默认缓存，先判断本地缓存，无缓存则取网络数据
        - NSURLRequestReturnCacheDataElseLoad | NSURLRequestReloadRevalidatingCacheData 先判断本地缓存，再返回网络数据（可能会回调两次）
        - NSURLRequestReloadIgnoringLocalCacheData | NSURLRequestReloadIgnoringLocalAndRemoteCacheData | NSURLRequestReloadIgnoringCacheData 忽略缓存，只取网络
        - NSURLRequestReturnCacheDataDontLoad 只取缓存，离线模式
 @param taskIdentifier        当前任务标识，请保证唯一性
 @param downloadProgressBlock 下载进度回调
 @param success               下载成功回调
 @param failure               下载失败回调
 @return                      NSURLSessionDownloadTask
 */
- (NSURLSessionDownloadTask *)CJFileDownLoadWithUrl:(NSURL *)url
                                         cachePolicy:(NSURLRequestCachePolicy)cachePolicy
                                      taskIdentifier:(id)taskIdentifier
                                            progress:(void (^)(id taskIdentifier, NSProgress *downloadProgress)) downloadProgressBlock
                                             success:(void (^)(id taskIdentifier       /** 当前任务标识 */,
                                                               BOOL cache,             /** 返回的是否为缓存数据，YES是缓存，此时的response为nil */
                                                               NSURLResponse *response /** 下载成功response */,
                                                               NSURL *filePath         /** 缓存路径 */,
                                                               NSString *MIMEType      /** 文件类型 */))success
                                             failure:(void (^)(id taskIdentifier, NSInteger statusCode, NSError *error))failure;

/**
 下载文件，设置请求参数，设置cookies，自定义缓存策略，设置自定义的缓存文件夹，并标识当前Task
 注意⚠️：customCachePath 自定义缓存路径是指存储下载文件的父级目录，下载将自动生成服务器返回的文件名，并将其放到该目录下
 
 @param url                  下载文件地址
 @param parameters           请求参数
 @param cookies              cookies
 @param cachePolicy          缓存策略
         - NSURLRequestUseProtocolCachePolicy 默认缓存，先判断本地缓存，无缓存则取网络数据
         - NSURLRequestReturnCacheDataElseLoad | NSURLRequestReloadRevalidatingCacheData 先判断本地缓存，再返回网络数据（可能会回调两次）
         - NSURLRequestReloadIgnoringLocalCacheData | NSURLRequestReloadIgnoringLocalAndRemoteCacheData | NSURLRequestReloadIgnoringCacheData 忽略缓存，只取网络
         - NSURLRequestReturnCacheDataDontLoad 只取缓存，离线模式
 @param customCachePath       注意⚠️：只能是文件夹，不能具体到文件路径！！！自定义的缓存路径（nil或者为空，取默认值：NSCachesDirectory 路径下的 CJFileDownLoad 文件夹）
 @param taskIdentifier        当前任务标识，请保证唯一性
 @param downloadProgressBlock 下载进度回调
 @param success               下载成功回调
 @param failure               下载失败回调
 @return                      NSURLSessionDownloadTask
 */
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
                                             failure:(void (^)(id taskIdentifier, NSInteger statusCode, NSError *error))failure;

/**
 下载文件，设置请求参数，设置cookies，自定义缓存策略，设置自定义缓存文件的路径
 注意⚠️：谨慎使用！！！
 1、区别与上一个方法，这里的downloadFileCachePath 设置的是自定义缓存文件的路径
 2、如果定义了下载文件的缓存路径以及文件名，那么下载后该文件事一定存在的，需要调用方在使用的时候再次判断文件是否为实际下载的文件
 举例：假如 downloadFileCachePath = xxx/text.png，
        a.那么成功下载后 text.png 是有效的png图片；
        b.如果服务器校验出错，返回了 {"code":"606","message":"user session does not exist, please re-auto-token-login."}，那么text.png 文件同样存在，只不过其内容为返回的json内容
 

 @param url                   下载文件地址
 @param parameters            请求参数
 @param cookies               cookies
 @param cachePolicy           缓存策略
 @param downloadFileCachePath 缓存文件的路径
 @param downloadProgressBlock 下载进度回调
 @param success               下载成功回调
 @param failure               下载失败回调
 @return NSURLSessionDownloadTask
 */
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
                                             failure:(void (^)(NSInteger statusCode, NSError *error))failure;

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
                                    failure:(void (^)(NSInteger statusCode, NSError *error))failure;

/**
 上传文件

 @param url                 文件上传地址
 @param parameters          请求参数
 @param cookies             cookies
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
                                       name:(NSString *)name
                                   fromData:(NSData *)fromData
                                   progress:(void (^)(NSProgress *uploadProgress))uploadProgressBlock
                                    success:(void (^)(NSURLResponse *response, id responseObject))success
                                    failure:(void (^)(NSInteger statusCode, NSError *error))failure;

/**
 上传文件

 @param url                 文件上传地址
 @param parameters          请求参数
 @param cookies             cookies
 @param name                与上传数据关联的名称，需要与服务器约定，注意⚠️不是文件名（默认：file）
 @param fileURL             上传文件的本地路径
 @param uploadProgressBlock 上传进度
 @param success             上传成功回调
 @param failure             上传失败回调
 @return                    NSURLSessionDataTask
 */
- (NSURLSessionDataTask *)uploadTaskWithUrl:(NSString *)url
                                 parameters:(id)parameters
                                    cookies:(NSDictionary <NSString*, NSString*>*)cookies
                                       name:(NSString *)name
                                   fromFile:(NSURL *)fileURL
                                   progress:(void (^)(NSProgress *uploadProgress))uploadProgressBlock
                                    success:(void (^)(NSURLResponse *response, id responseObject))success
                                    failure:(void (^)(NSInteger statusCode, NSError *error))failure;

/**
 批量上传文件

 @param url                 文件上传地址
 @param parameters          请求参数
 @param cookies             cookies
 @param name                与上传数据关联的名称，需要与服务器约定，注意⚠️不是文件名（默认：file）
 @param fileList            上传文件的本地路径数组
 @param uploadProgressBlock 上传进度
 @param success             上传成功回调
 @param failure             上传失败回调
 */
- (void)uploadTaskWithUrl:(NSString *)url
               parameters:(id)parameters
                  cookies:(NSDictionary <NSString*, NSString*>*)cookies
                     name:(NSString *)name
             fromFileList:(NSArray <NSURL *>*)fileList
                 progress:(void (^)(NSURL *fileURL, NSProgress *uploadProgress))uploadProgressBlock
                  success:(void (^)(NSURL *fileURL, NSURLResponse *response, id responseObject))success
                  failure:(void (^)(NSURL *fileURL, NSInteger statusCode, NSError *error))failure;

/**
 上传二进制文件

 @param url                 文件上传地址
 @param parameters          请求参数
 @param cookies             cookies
 @param bodyData            二进制数据
 @param uploadProgressBlock 上传进度
 @param success             上传成功回调
 @param failure             上传失败回调
 @return                    NSURLSessionUploadTask
 */
- (NSURLSessionUploadTask *)uploadTaskWithUrl:(NSString *)url
                                   parameters:(id)parameters
                                      cookies:(NSDictionary <NSString*, NSString*>*)cookies
                                     fromData:(NSData *)bodyData
                                     progress:(void (^)(NSProgress *uploadProgress))uploadProgressBlock
                                      success:(void (^)(NSURLResponse *response, id responseObject))success
                                      failure:(void (^)(NSInteger statusCode, NSError *error))failure;


/**
 流文件上传

 @param request             上传请求
 @param uploadProgressBlock 上传进度
 @param success             上传成功回调
 @param failure             上传失败回调
 @return                    NSURLSessionUploadTask
 */
- (NSURLSessionUploadTask *)uploadTaskWithStreamedRequest:(NSMutableURLRequest *)request
                                                 progress:(void (^)(NSProgress *uploadProgress))uploadProgressBlock
                                                  success:(void (^)(NSURLResponse *response, id responseObject))success
                                                  failure:(void (^)(NSInteger statusCode, NSError *error))failure;
@end

