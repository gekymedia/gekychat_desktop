import 'package:livekit_client/livekit_client.dart';

/// High-quality LiveKit defaults for GekyChat desktop calls & broadcasts.
class LiveKitQuality {
  LiveKitQuality._();

  static const VideoEncoding callVideoEncoding = VideoEncoding(
    maxBitrate: 2500 * 1000,
    maxFramerate: 30,
  );

  static const VideoEncoding broadcastVideoEncoding = VideoEncoding(
    maxBitrate: 4500 * 1000,
    maxFramerate: 30,
  );

  static const VideoEncoding screenShareEncoding = VideoEncoding(
    maxBitrate: 4000 * 1000,
    maxFramerate: 30,
  );

  static RoomOptions callRoomOptions() {
    return const RoomOptions(
      adaptiveStream: false,
      dynacast: true,
      defaultCameraCaptureOptions: CameraCaptureOptions(
        cameraPosition: CameraPosition.front,
        params: VideoParametersPresets.h720_169,
      ),
      defaultScreenShareCaptureOptions: ScreenShareCaptureOptions(
        maxFrameRate: 30,
        params: VideoParametersPresets.screenShareH1080FPS30,
      ),
      defaultAudioCaptureOptions: AudioCaptureOptions(
        echoCancellation: true,
        noiseSuppression: true,
        autoGainControl: true,
        highPassFilter: true,
      ),
      defaultVideoPublishOptions: VideoPublishOptions(
        simulcast: true,
        videoEncoding: callVideoEncoding,
        screenShareEncoding: screenShareEncoding,
        videoSimulcastLayers: [
          VideoParametersPresets.h180_169,
          VideoParametersPresets.h360_169,
        ],
      ),
      defaultAudioPublishOptions: AudioPublishOptions(
        dtx: true,
      ),
    );
  }

  static RoomOptions broadcastHostRoomOptions() {
    return const RoomOptions(
      adaptiveStream: false,
      dynacast: true,
      defaultCameraCaptureOptions: CameraCaptureOptions(
        cameraPosition: CameraPosition.front,
        params: VideoParametersPresets.h1080_169,
      ),
      defaultScreenShareCaptureOptions: ScreenShareCaptureOptions(
        maxFrameRate: 30,
        params: VideoParametersPresets.screenShareH1080FPS30,
      ),
      defaultAudioCaptureOptions: AudioCaptureOptions(
        echoCancellation: true,
        noiseSuppression: true,
        autoGainControl: true,
        highPassFilter: true,
      ),
      defaultVideoPublishOptions: VideoPublishOptions(
        simulcast: true,
        videoEncoding: broadcastVideoEncoding,
        screenShareEncoding: screenShareEncoding,
        videoSimulcastLayers: [
          VideoParametersPresets.h180_169,
          VideoParametersPresets.h360_169,
          VideoParametersPresets.h720_169,
        ],
      ),
      defaultAudioPublishOptions: AudioPublishOptions(
        dtx: true,
      ),
    );
  }

  static RoomOptions viewerRoomOptions() {
    return const RoomOptions(
      adaptiveStream: true,
      dynacast: true,
    );
  }

  static ScreenShareCaptureOptions screenShareCaptureOptions({
    String? sourceId,
  }) {
    return ScreenShareCaptureOptions(
      sourceId: sourceId,
      maxFrameRate: 30,
      params: VideoParametersPresets.screenShareH1080FPS30,
    );
  }

  static const VideoPublishOptions screenSharePublishOptions = VideoPublishOptions(
    simulcast: true,
    screenShareEncoding: screenShareEncoding,
  );
}
