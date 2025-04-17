// 目前目標做到
//  1.在照片預覽的時候，相機為暫停，防止耗能，雖然說現在的手機一定能夠撐住開著相機畫面並且做其他事情。但就是防止一切可能性。
//  2.再刪除照片時可以跳著選擇並且刪除。
//  3.連拍的照片可以預覽
//  4.輸出內容為多像並且有提供Base64轉換

import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

import 'dart:developer' as developer;

void devLog(String name, String message) {
  developer.log(message, name: name);
}

class ImageInfo {
  final String path;
  final int size;
  final String fileBase64;

  ImageInfo({required this.path, required this.size, required this.fileBase64});

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'size': size,
      'file': fileBase64,
    };
  }

  //複寫 toString()
  //讓它顯示我想顯示的東西
  @override
  String toString() {
    return jsonEncode(toJson()); // 使用 jsonEncode 轉換 toJson() 返回的映射
  }
}

class CameraViewPage extends StatefulWidget {
  const CameraViewPage({super.key});

  @override
  State<CameraViewPage> createState() => _CameraViewPageState();
}

class _CameraViewPageState extends State<CameraViewPage> {
  CameraController? cameraController;
  XFile? imageFile;
  List<XFile> imageFiles = [];

  Set<int> selectedIndex = {};

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    initCamera();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    cameraController?.dispose();
    super.dispose();
  }

  //相機初始化
  Future<void> initCamera() async {
    //啟用相機
    final cameras = await availableCameras();
    //設定鏡頭為後置鏡頭
    //要改前置 => CameraLensDirection.front
    CameraDescription backCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
    );
    cameraController = CameraController(backCamera, ResolutionPreset.high);

    //啟動後更新UI
    cameraController?.initialize().then((_) {
      cameraController!.setFlashMode(FlashMode.off);
      if (!mounted) return;
      setState(() {});
    });

    
    
  }

  //拍照
  Future<void> takePicture() async {
    if (!cameraController!.value.isInitialized) {
      return;
    }
    if (cameraController!.value.isTakingPicture) {
      return;
    }

    imageFile = await cameraController!.takePicture();
    await cameraController!.pausePreview();

    devLog('相機暫停', "相機暫停了");
    setState(() {});
  }

  //刪除當前拍攝的照片
  Future<void> retakePicture() async {
    await cameraController!.resumePreview();
    devLog('相機回復', "相機回復了");
    setState(() {
      imageFile = null;
    });
  }

  //儲存圖片至list
  Future<void> savePicture() async {
    if (imageFile != null) {
      await cameraController!.resumePreview();
      setState(() {
        imageFiles.add(imageFile!);
        imageFile = null;
      });
    }
  }

  //刪除照片邏輯
  //刪除Set列組資料
  void deleteSelectedPictures() {
    if (selectedIndex.isNotEmpty) {
      setState(() {
        // 從大到小排序索引
        List<int> sortedIndices = selectedIndex.toList()
          ..sort((a, b) => b.compareTo(a));
        // 反向遍歷並刪除，確保所有索引都在當前列表範圍內
        for (int index in sortedIndices) {
          if (index >= 0 && index < imageFiles.length) {
            imageFiles.removeAt(index);
          }
        }
        selectedIndex.clear();
      });
    }
  }

  //將資料存進ImageInfo
  Future<List<ImageInfo>> processImageFiles() async {
    List<ImageInfo> imageInfoList = [];

    for (XFile image in imageFiles) {
      try {
        File filePath = File(image.path);
        int size = await filePath.length();
        List<int> imageBytes = await filePath.readAsBytes();
        String base64String = base64Encode(imageBytes);
        imageInfoList.add(
            ImageInfo(path: image.path, size: size, fileBase64: base64String));
      } catch (e) {
        devLog("Error processing image file:", e.toString());
        //假如這張照片出錯就跳過這張照片
        continue;
      }
    }
    //顯示圖片資料庫
    //devLog("圖片資料庫資料", imageInfoList.toString());

    return imageInfoList;
  }

  // 也可以將printImageFilesDetailed()改變成<bool>的格式進行Api的上傳
  //
  // Future<bool> uploadFile(Map<String,dynamic> imageFiles)async{

  //   //進行一些Api上傳之類的事情

  //   if(){
  //     return true;
  //   }else{
  //     return false;
  //   }

  // }

  void showFinishDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("上傳完成"),
          content: const Text("所有照片已上傳完成。"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('確定'),
            )
          ],
        );
      },
    );
  }

  void showErrorDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("上傳失敗"),
          content: const Text("照片上傳失敗。"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('確定'),
            )
          ],
        );
      },
    );
  }

  // #2
  Widget cameraPreview() {
    final Size size = MediaQuery.of(context).size;
    final double aspectRatio = cameraController!.value.aspectRatio;

    // calculate scale depending on screen and camera ratios
    // this is actually size.aspectRatio / (1 / camera.aspectRatio)
    // because camera preview size is received as landscape
    // but we're calculating for portrait orientation
    var scale = size.aspectRatio * aspectRatio;

    // to prevent scaling down, invert the value
    if (scale < 1) scale = 1 / (scale + 0.1);

    return Transform.scale(
      scale: scale,
      child: Center(
        child: CameraPreview(cameraController!),
      ),
    );
  }

  // #1
  // Widget cameraPreview() {
  //   return AspectRatio(
  //     aspectRatio: 1 / cameraController!.value.aspectRatio,
  //     child: CameraPreview(cameraController!),
  //   );
  // }

  //拍完照片的預覽圖
  Widget thumbnailPreview() {
    final Size size = MediaQuery.of(context).size;
    final double aspectRatio = cameraController!.value.aspectRatio;
    var scale = size.aspectRatio * aspectRatio;

    if (scale < 1) scale = 1 / (scale + 0.1);

    return Transform.scale(
      scale: scale,
      child: Center(
        child: Image.file(
          File(imageFile!.path),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget previewOverlay() {
    //假如沒有使用Expanded 這邊就會因為沒有給予Row大小而全部縮再一起
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: retakePicture,
                icon: const Icon(Icons.refresh),
              ),
              const Text("重新拍攝"),
            ],
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: savePicture,
                icon: const Icon(Icons.check),
              ),
              const Text("儲存圖片"),
            ],
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('cameraViewPage'),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 7,
            child:
                // 問題1：到目前截止(2024/04/29)在使用CameraPreview(cameraController)進行相機畫面預覽時，必定會遇上畫面拉伸問題
                // 　　　 不管是使用達到BoxFit.cover的效果
                //       1. ClipRect() + OverflowBox() + FittedBox(fit: BoxFit.cover)
                //
                //        * Camera package version v0.7.0
                //
                //           2. Transform.scale切割方式
                //
                //       目前無法達成像ImagePicker的全畫面相機縮放效果
                //
                // #1
                //     ClipRect(
                //   child: OverflowBox(
                //     // 使用OverflowBox允許視頻超出父元件的範圍，達到BoxFit.cover的效果。
                //     alignment: Alignment.center,
                //     child: FittedBox(
                //       fit: BoxFit.cover,
                //       child: SizedBox(
                //         height: 1,
                //         child: Stack(
                //           children: [
                //             if (cameraController != null &&
                //                 cameraController!.value.isInitialized)
                //               cameraPreview(),
                //             if (imageFile != null) thumbnailPreview(),
                //           ],
                //         ),
                //       ),
                //     ),
                //   ),
                // ),
                Stack(
              children: [
                if (cameraController != null &&
                    cameraController!.value.isInitialized)
                  cameraPreview(),
                if (imageFile != null) thumbnailPreview(),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              children: [
                const SizedBox(height: 30),
                SizedBox(
                  height: 70,
                  child: GridView.builder(
                    scrollDirection: Axis.horizontal,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 1,
                    ),
                    itemCount: imageFiles.length,
                    itemBuilder: (context, index) {
                      bool isSelected = selectedIndex.contains(index);
                      return InkWell(
                        onLongPress: () {
                          setState(() {
                            if (isSelected) {
                              selectedIndex.remove(index);
                              devLog('選擇的Set', selectedIndex.toString());
                            } else {
                              selectedIndex.add(index);
                              devLog('選擇的Set', selectedIndex.toString());
                            }
                          });
                        },
                        // #1 第一種-直接顯示dialog的方式
                        // onTap: () {
                        //   showDialog(
                        //     context: context,
                        //     builder: (BuildContext context) {
                        //       return AlertDialog(
                        //         content: Image.file(
                        //           File(imageFiles[index].path),
                        //         ),
                        //       );
                        //     },
                        //   );
                        // },
                        // #2 第二種-使用到插件photo_view
                        // onTap: () {
                        //   Navigator.of(context).push(
                        //     MaterialPageRoute(
                        //       builder: (context) => Scaffold(
                        //         appBar: AppBar(
                        //           backgroundColor: Colors.black,
                        //           iconTheme:
                        //               const IconThemeData(color: Colors.white),
                        //         ),
                        //         body: Container(
                        //           color: Colors.black, // 選擇一個背景顏色
                        //           child: PhotoView(
                        //             imageProvider:
                        //                 FileImage(File(imageFiles[index].path)),
                        //           ),
                        //         ),
                        //       ),
                        //     ),
                        //   );
                        // },
                        // #3 第三種-兩種結合
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return Dialog(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                surfaceTintColor: Colors.transparent,
                                child: SizedBox(
                                  width: 150,
                                  height: 400,
                                  child: PhotoView(
                                    backgroundDecoration: const BoxDecoration(
                                      color: Colors.transparent,
                                    ),
                                    imageProvider: FileImage(
                                      File(imageFiles[index].path),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Image.file(
                                File(imageFiles[index].path),
                                fit: BoxFit.contain,
                              ),
                            ),
                            if (isSelected)
                              const Positioned(
                                right: 15,
                                top: 1,
                                child: Icon(
                                  Icons.check_circle,
                                  color: Colors.red,
                                  size: 24,
                                ),
                              )
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    if (imageFile == null)
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: deleteSelectedPictures,
                            icon: const Icon(Icons.delete),
                            tooltip: "刪除選中的照片",
                          ),
                          const Text("刪除照片"),
                        ],
                      ),
                    imageFile == null
                        ? FloatingActionButton(
                            onPressed: takePicture,
                            child: const Icon(Icons.camera),
                          )
                        : previewOverlay(),
                    if (imageFile == null)
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: () async {
                              List<ImageInfo> images =
                                  await processImageFiles();
                              if (images.isNotEmpty) {
                                showFinishDialog(); // 有數據時顯示完成對話框
                              } else {
                                showErrorDialog(); // 無有效數據時顯示錯誤對話框
                              }
                            },
                            icon: const Icon(Icons.file_upload_outlined),
                          ),
                          const Text("上傳"),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
