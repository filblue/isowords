import AudioPlayerClient
import Bloom
import ComposableArchitecture
import CubeCore
import FeedbackGeneratorClient
import HapticsCore
import LowPowerModeClient
import SelectionSoundsCore
import SharedModels
import Styleguide
import SwiftUI

public struct CubePreviewState: Equatable {
  var cubes: Puzzle
  var isAnimationReduced: Bool
  var isHapticsEnabled: Bool
  var isOnLowPowerMode: Bool
  var moveIndex: Int
  var moves: Moves
  @BindableState var nub: CubeSceneView.ViewState.NubState
  @BindableState var selectedCubeFaces: [IndexedCubeFace]
  let settings: CubeSceneView.ViewState.Settings

  public init(
    cubes: ArchivablePuzzle,
    isAnimationReduced: Bool,
    isHapticsEnabled: Bool,
    isOnLowPowerMode: Bool = false,
    moveIndex: Int,
    moves: Moves,
    nub: CubeSceneView.ViewState.NubState = .init(),
    selectedCubeFaces: [IndexedCubeFace] = [],
    settings: CubeSceneView.ViewState.Settings
  ) {
    self.cubes = .init(archivableCubes: cubes)
    apply(moves: moves[0..<moveIndex], to: &self.cubes)

    self.isAnimationReduced = isAnimationReduced
    self.isHapticsEnabled = isHapticsEnabled
    self.isOnLowPowerMode = isOnLowPowerMode
    self.moveIndex = moveIndex
    self.moves = moves
    self.nub = nub
    self.selectedCubeFaces = selectedCubeFaces
    self.settings = settings
  }

  var finalWordString: String? {
    switch self.moves[self.moveIndex].type {
    case let .playedWord(faces):
      return self.cubes.string(from: faces)
    case .removedCube:
      return nil
    }
  }
}

public enum CubePreviewAction: BindableAction, Equatable {
  case binding(BindingAction<CubePreviewState>)
  case cubeScene(CubeSceneView.ViewAction)
  case lowPowerModeResponse(Bool)
  case onAppear
  case tap
}

public struct CubePreviewEnvironment {
  var audioPlayer: AudioPlayerClient
  var feedbackGenerator: FeedbackGeneratorClient
  var lowPowerMode: LowPowerModeClient
  var mainQueue: AnySchedulerOf<DispatchQueue>

  public init(
    audioPlayer: AudioPlayerClient,
    feedbackGenerator: FeedbackGeneratorClient,
    lowPowerMode: LowPowerModeClient,
    mainQueue: AnySchedulerOf<DispatchQueue>
  ) {
    self.audioPlayer = audioPlayer
    self.feedbackGenerator = feedbackGenerator
    self.lowPowerMode = lowPowerMode
    self.mainQueue = mainQueue
  }
}

public let cubePreviewReducer = Reducer<
  CubePreviewState,
  CubePreviewAction,
  CubePreviewEnvironment
> { state, action, environment in

  enum SelectionId {}

  switch action {
  case .binding:
    return .none

  case .cubeScene:
    return .none

  case let .lowPowerModeResponse(isOn):
    state.isOnLowPowerMode = isOn
    return .none

  case .onAppear:
    return .run { [move = state.moves[state.moveIndex]] send in
      try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
          for await isLowPowerMode in await environment.lowPowerMode.startAsync() {
            await send(.lowPowerModeResponse(isLowPowerMode))
          }
        }

        group.addTask {
          try await environment.mainQueue.sleep(for: .seconds(1))

          var accumulatedSelectedFaces: [IndexedCubeFace] = []
          switch move.type {
          case let .playedWord(faces):
            for (faceIndex, face) in faces.enumerated() {
              accumulatedSelectedFaces.append(face)
              let moveDuration = Double.random(in: (0.6...0.8))

              await MainActor.run {
                UIView.animate(
                  withDuration: moveDuration, delay: 0, options: .curveEaseInOut
                ) {
                  send(.set(\.$nub.location, .face(face)), animation: .default)
                }
              }

              try await environment.mainQueue.sleep(
                for: .seconds(faceIndex == 0 ? moveDuration : 0.5 * moveDuration)
              )

              // Press the nub on the first character
              if faceIndex == 0 {
                await send(.set(\.$nub.isPressed, true), animation: .default)
              }

              // Select the faces that have been tapped so far
              await send(.set(\.$selectedCubeFaces, accumulatedSelectedFaces), animation: .default)
            }

            await send(.set(\.$nub.isPressed, false))
            await MainActor.run {
              UIView.animate(
                withDuration: 1, delay: 0, options: .curveEaseInOut
              ) {
                send(.set(\.$nub.location, .offScreenRight), animation: .default)
              }
            }
          case let .removedCube(index):
            break
          }
        }

        try await group.waitForAll()
      }
    }
    .cancellable(id: SelectionId.self)

  case .tap:
    state.nub.location = .offScreenRight
    switch state.moves[state.moveIndex].type {
    case let .playedWord(faces):
      state.selectedCubeFaces = faces
    case .removedCube:
      break
    }
    return .cancel(id: SelectionId.self)
  }
}
.binding()
.haptics(
  feedbackGenerator: \.feedbackGenerator,
  isEnabled: \.isHapticsEnabled,
  triggerOnChangeOf: { $0.selectedCubeFaces }
)
.selectionSounds(
  audioPlayer: \.audioPlayer,
  contains: { state, _, string in
    state.finalWordString?.uppercased() == string.uppercased()
  },
  hasBeenPlayed: { _, _ in false },
  puzzle: \.cubes,
  selectedWord: \.selectedCubeFaces
)
// TODO: cancel effects on dismiss

public struct CubePreviewView: View {
  @Environment(\.deviceState) var deviceState
  let store: Store<CubePreviewState, CubePreviewAction>
  @ObservedObject var viewStore: ViewStore<ViewState, CubePreviewAction>

  struct ViewState: Equatable {
    let isAnimationReduced: Bool
    let selectedWordIsFinalWord: Bool
    let selectedWordScore: Int?
    let selectedWordString: String

    init(state: CubePreviewState) {
      self.isAnimationReduced = state.isAnimationReduced
      self.selectedWordString = state.cubes.string(from: state.selectedCubeFaces)
      self.selectedWordIsFinalWord = state.finalWordString == self.selectedWordString
      self.selectedWordScore =
        self.selectedWordIsFinalWord
        ? state.moves[state.moveIndex].score
        : nil
    }
  }

  public init(store: Store<CubePreviewState, CubePreviewAction>) {
    self.store = store
    self.viewStore = ViewStore(self.store.scope(state: ViewState.init(state:)))
  }

  public var body: some View {
    GeometryReader { proxy in
      ZStack(alignment: .top) {
        if !self.viewStore.selectedWordString.isEmpty {
          (Text(self.viewStore.selectedWordString)
            + self.scoreText
            .baselineOffset(
              (self.deviceState.idiom == .pad ? 2 : 1) * 16
            )
            .font(
              .custom(
                .matterMedium,
                size: (self.deviceState.idiom == .pad ? 2 : 1) * 20
              )
            ))
            .adaptiveFont(
              .matterSemiBold,
              size: (self.deviceState.idiom == .pad ? 2 : 1) * 32
            )
            .opacity(self.viewStore.selectedWordIsFinalWord ? 1 : 0.5)
            .allowsTightening(true)
            .minimumScaleFactor(0.2)
            .lineLimit(1)
            .transition(.opacity)
            .animation(nil, value: self.viewStore.selectedWordString)
            .adaptivePadding(.top, .grid(16))
        }

        CubeView(
          store: self.store.scope(
            state: CubeSceneView.ViewState.init(preview:),
            action: CubePreviewAction.cubeScene
          )
        )
        .onAppear {
          self.viewStore.send(.onAppear)
        }
      }
      .background(
        self.viewStore.isAnimationReduced
          ? nil
          : BloomBackground(
            size: proxy.size,
            store: self.store.actionless
              .scope(
                state: { _ in
                  BloomBackground.ViewState(
                    bloomCount: self.viewStore.selectedWordString.count,
                    word: self.viewStore.selectedWordString
                  )
                }
              )
          )
      )
    }
    .onTapGesture {
      UIView.setAnimationsEnabled(false)
      self.viewStore.send(.tap)
      UIView.setAnimationsEnabled(true)
    }
  }

  var scoreText: Text {
    self.viewStore.selectedWordScore.map {
      Text(" \($0)")
    } ?? Text("")
  }
}

extension CubeSceneView.ViewState {
  public init(preview state: CubePreviewState) {
    let selectedWordString = state.cubes.string(from: state.selectedCubeFaces)

    self.init(
      cubes: state.cubes.enumerated().map { x, cubes in
        cubes.enumerated().map { y, cubes in
          cubes.enumerated().map { z, cube in
            let index = LatticePoint.init(x: x, y: y, z: z)
            return CubeNode.ViewState(
              cubeShakeStartedAt: nil,
              index: .init(x: x, y: y, z: z),
              isCriticallySelected: false,
              isInPlay: cube.isInPlay,
              left: .init(
                cubeFace: .init(
                  letter: cube.left.letter,
                  side: .left
                ),
                status: state.selectedCubeFaces.contains(.init(index: index, side: .left))
                  ? .selected
                  : .deselected
              ),
              right: .init(
                cubeFace: .init(letter: cube.right.letter, side: .right),
                status: state.selectedCubeFaces.contains(.init(index: index, side: .right))
                  ? .selected
                  : .deselected
              ),
              top: .init(
                cubeFace: .init(letter: cube.top.letter, side: .top),
                status: state.selectedCubeFaces.contains(.init(index: index, side: .top))
                  ? .selected
                  : .deselected
              )
            )
          }
        }
      },
      isOnLowPowerMode: state.isOnLowPowerMode,
      nub: state.nub,
      playedWords: [],
      selectedFaceCount: state.selectedCubeFaces.count,
      selectedWordIsValid: selectedWordString == state.finalWordString,
      selectedWordString: selectedWordString,
      settings: state.settings
    )
  }
}
