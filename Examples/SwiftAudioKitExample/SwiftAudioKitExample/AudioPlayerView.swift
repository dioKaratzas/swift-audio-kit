import SwiftUI

struct AudioPlayerView: View {
    @StateObject
    private var audioPlayerManager = AudioPlayerManager()

    var body: some View {
        VStack {
            Text(audioPlayerManager.currentTrackTitle)
                .font(.title)
                .padding()

            HStack {
                Button(action: {
                    audioPlayerManager.previousTrack()
                }) {
                    Image(systemName: "backward.fill")
                        .font(.largeTitle)
                }
                .padding()

                Button(action: {
                    if audioPlayerManager.isPlaying {
                        audioPlayerManager.pause()
                    } else {
                        audioPlayerManager.play()
                    }
                }) {
                    Image(systemName: audioPlayerManager.isPlaying ? "pause.fill" : "play.fill")
                        .font(.largeTitle)
                }
                .padding()

                Button(action: {
                    audioPlayerManager.nextTrack()
                }) {
                    Image(systemName: "forward.fill")
                        .font(.largeTitle)
                }
                .padding()
            }
        }
    }
}

struct AudioPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        AudioPlayerView()
    }
}
