
Pod::Spec.new do |s|
  s.name             = 'CJFileDownloader'
  s.version          = '1.0.0'
  s.summary          = '文件下载、上传管理器， 支持任意文件下载，断点下载，导出缓存路径；以及单文件上传和批量文件上传。'

  s.description      = <<-DESC
  文件下载、上传管理器， 支持任意文件下载，断点下载，导出缓存路径；以及单文件上传和批量文件上传。
                       DESC

  s.homepage         = 'https://github.com/lele8446/CJFileDownloader'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'lele8446' => 'lele8446@foxmail.com' }
  s.source           = { :git => 'https://github.com/lele8446/CJFileDownloader.git', :tag => s.version.to_s }

  s.ios.deployment_target = '9.0'

  s.public_header_files = 'CJFileDownloader/Classes/**/*.h'
  s.source_files = 'CJFileDownloader/Classes/**/*'

  s.dependency 'AFNetworking'

  # s.resource_bundles = {
  #   'CJFileDownloader' => ['CJFileDownloader/Assets/*.png']
  # }
  # s.frameworks = 'UIKit', 'MapKit'

end
