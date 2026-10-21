import SwiftUI

struct AppRootView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.bookCourseReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase
  @State private var assistantTop: CGFloat?
  @State private var assistantLeft = false
  @State private var lessonAssistantTop: CGFloat?
  @State private var lessonAssistantLeft = false
  var body: some View {
    GeometryReader { geometry in
      let pad =
        geometry.size.width >= 720
        && geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom
          >= 600
      HStack(spacing: 0) {
        if pad, store.route.showsPrimaryNavigation {
          PadRail(
            expandedWidth: min(232, max(208, geometry.size.width * 0.22)),
            topInset: max(0, 32 - geometry.safeAreaInsets.top))
        }
        VStack(spacing: 0) {
          if !store.route.hidesHeader {
            BCHeader(
              store.route == .courseDetail ? store.currentTitle : store.route.title,
              back: store.route.isTab
                || [.courseReady, .courseImportReady, .communityImport].contains(store.route)
                ? nil : { store.back() },
              titleColor: store.route == .upload ? .white : DS.text
            ).padding(.top, pad ? max(0, 62 - geometry.safeAreaInsets.top) : 0).padding(
              .horizontal, pad ? 16 : 0)
          }
          screen.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.safeAreaInset(edge: .bottom, spacing: 0) {
          if !pad, store.route.showsPrimaryNavigation {
            PhoneBottomBar().padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 6)
              .background { ProgressiveMaterial().ignoresSafeArea(edges: .bottom) }
          }
        }
      }
      .background(pageBackground)
      .overlay {
        if !store.isLoading,
          ![
            Route.onboarding, .courseSetup, .upload, .parseReady, .processing,
            .courseImportProcessing, .chapterConfirm, .courseReady, .courseImportReady,
            .communityImport, .voiceNote, .source, .notes, .profile, .settings,
            .communityBook,
          ].contains(store.route), store.sheet == nil, !store.globalAssistantOpen,
          !(store.route == .lesson && store.learningState.readerOverlayVisible)
        {
          FloatingAssistant(
            windowSize: CGSize(
              width: geometry.size.width + geometry.safeAreaInsets.leading
                + geometry.safeAreaInsets.trailing,
              height: geometry.size.height + geometry.safeAreaInsets.top
                + geometry.safeAreaInsets.bottom), safeArea: geometry.safeAreaInsets,
            navHeight: (!pad && store.route.showsPrimaryNavigation) ? 72 : 0,
            lessonEntry: store.route == .lesson,
            top: store.route == .lesson ? $lessonAssistantTop : $assistantTop,
            left: store.route == .lesson ? $lessonAssistantLeft : $assistantLeft)
        }
      }
      .overlay {
        if let sheet = store.sheet {
          AppOverlay(sheet: sheet).transition(
            reduceMotion ? .identity : .opacity.combined(with: .scale(scale: 0.97)))
        }
      }
      .overlay {
        if store.globalAssistantOpen {
          GlobalAssistantOverlay().transition(
            reduceMotion ? .identity : .opacity.combined(with: .scale(scale: 0.97)))
        }
      }
      .overlay(alignment: .top) {
        if let toast = store.toast {
          Text(toast).font(DS.font(14, weight: .semibold)).foregroundStyle(DS.text).padding(
            .horizontal, 18
          ).padding(.vertical, 12).background(.white, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(DS.border, lineWidth: 1)).shadow(
              color: .black.opacity(0.08), radius: 12, y: 4
            ).padding(.horizontal, 20).padding(.top, 8).accessibilityAddTraits(.updatesFrequently)
            .allowsHitTesting(false)
        }
      }
      .overlay {
        if store.isLoading {
          VStack(spacing: 18) {
            AssetImage("/assets/brand/cloud-mascot-home.png").frame(width: 130, height: 130)
            ProgressView().tint(DS.primary)
            Text("正在准备学习空间").font(DS.font(14)).foregroundStyle(DS.secondary)
          }.frame(maxWidth: .infinity, maxHeight: .infinity).background(DS.background)
        }
      }
      .overlay {
        if let error = store.bootError {
          VStack(spacing: 16) {
            EmptyStateView(
              title: "学习空间暂时无法打开", message: error,
              asset: "/assets/brand/empty-states/connection-error-v1.png")
            BCButton("重新加载") {
              store.bootError = nil
              store.isLoading = true
              Task { await store.boot() }
            }
          }.padding(24).background(DS.background)
        }
      }
      .onAppear {
        store.isPad = pad
        FixtureOrientation.apply()
      }
      .onChange(of: pad) { _, value in store.isPad = value }
      .animation(reduceMotion ? nil : DS.localAnimation, value: store.sheet)
    }
    .background(pageBackground.ignoresSafeArea()).font(DS.font()).foregroundStyle(DS.text).tint(
      DS.primary
    )
    .onChange(of: scenePhase) { _, phase in if phase != .active { store.persist() } }
  }
  private var pageBackground: Color {
    switch store.route {
    case .assignment: Color(hex: 0xd9d2ff)
    case .source, .lesson, .processing, .courseImportProcessing, .chapterConfirm, .mistakes: .white
    case .parseReady, .communityBook: Color(hex: 0xddd6fe)
    case .upload: Color(hex: 0xdccafa)
    default: DS.background
    }
  }
  @ViewBuilder private var screen: some View {
    switch store.route {
    case .study, .plan, .flashcards, .lesson, .assignment, .diagnosis, .mistakes, .export:
      LearningRouterView(route: store.route)
    case .notes, .voiceNote, .source: NotesRouterView(route: store.route)
    default: CoursesRouterView(route: store.route)
    }
  }
}
private let primaryTabs: [Route] = [.home, .study, .community, .profile]
private func isCurrentTab(_ tab: Route, _ route: Route) -> Bool {
  tab == route || (tab == .home && route == .courseDetail)
}
struct PhoneBottomBar: View {
  @Environment(AppStore.self) private var store
  @Namespace private var selection
  @Environment(\.bookCourseReduceMotion) private var reduceMotion
  var body: some View {
    HStack(spacing: 0) {
      ForEach(primaryTabs) { tab in
        Button {
          withAnimation(reduceMotion ? nil : DS.globalAnimation) { store.go(tab) }
        } label: {
          VStack(spacing: 6) {
            SVGAsset(
              path:
                "icons/nav-\(tab.rawValue)-\(isCurrentTab(tab,store.route) ? "selected-white":"normal").svg"
            ).frame(width: 22, height: 22)
            Text(tab == .community ? "发现" : tab.title).font(
              DS.font(14, weight: isCurrentTab(tab, store.route) ? .bold : .regular))
          }
          .foregroundStyle(isCurrentTab(tab, store.route) ? .white : DS.muted).frame(
            maxWidth: .infinity
          ).frame(height: 56)
          .background {
            if isCurrentTab(tab, store.route) {
              Capsule().fill(DS.primary).matchedGeometryEffect(id: "tab", in: selection)
            }
          }
          .contentShape(Capsule())
        }.buttonStyle(BCPressStyle()).accessibilityIdentifier("tab-" + tab.rawValue)
          .accessibilityAddTraits(isCurrentTab(tab, store.route) ? [.isSelected] : [])
      }
    }.padding(8).frame(height: 72).background(.white.opacity(0.88), in: Capsule()).overlay(
      Capsule().stroke(.white.opacity(0.78), lineWidth: 1)
    ).shadow(color: Color(hex: 0x364e7e).opacity(0.14), radius: 16, y: 8)
  }
}
struct PadRail: View {
  var expandedWidth: CGFloat = 220
  var topInset: CGFloat = 8
  @Environment(AppStore.self) private var store
  @Environment(\.bookCourseReduceMotion) private var reduceMotion
  @State private var expanded = false
  var body: some View {
    VStack(spacing: 4) {
      VStack(spacing: 4) {
        Button {
          withAnimation(reduceMotion ? nil : DS.globalAnimation) { expanded.toggle() }
        } label: {
          BCGlyph(expanded ? "PanelLeftClose" : "PanelLeftOpen", color: .white.opacity(0.75)).frame(
            width: 20, height: 20
          ).frame(maxWidth: .infinity, minHeight: 44, alignment: expanded ? .trailing : .center)
        }.buttonStyle(.plain).accessibilityLabel(expanded ? "收起侧栏" : "展开侧栏")
        HStack(spacing: 10) {
          AssetImage("/assets/brand/app-logo.png").frame(width: 32, height: 32).clipShape(
            RoundedRectangle(cornerRadius: 11))
          if expanded {
            Text("BookCourse AI").font(DS.font(20, weight: .bold)).foregroundStyle(.white)
            Spacer()
          }
        }.frame(height: 32)
      }.padding(.bottom, 8)
      ForEach(Array(primaryTabs.prefix(3))) { tab in tabButton(tab) }
      if expanded, store.route == .study {
        VStack(alignment: .leading, spacing: 8) {
          Text(store.currentTitle).font(DS.font(14, weight: .bold)).foregroundStyle(.white)
            .lineLimit(2).padding(.vertical, 10)
          ForEach([Route.plan, .flashcards, .assignment, .mistakes, .notes]) { route in
            Button {
              store.go(route)
            } label: {
              Text(route.title).font(DS.font(14)).foregroundStyle(.white.opacity(0.8)).frame(
                maxWidth: .infinity, minHeight: 38, alignment: .leading)
            }.buttonStyle(.plain)
          }
          Button("切换课程") { store.openSheet(.bookSwitcher) }.font(DS.font(14)).foregroundStyle(
            .white.opacity(0.8))
        }.padding(.horizontal, 8)
      }
      Spacer(minLength: 0)
      tabButton(.profile)
    }.padding(.horizontal, 7).padding(.top, topInset).padding(.bottom, 0).frame(
      width: expanded ? expandedWidth : 58.6667
    ).background(Color(hex: 0x19191b).ignoresSafeArea())
  }
  private func tabButton(_ tab: Route) -> some View {
    Button {
      store.go(tab)
    } label: {
      HStack(spacing: 12) {
        SVGAsset(
          path:
            "icons/nav-\(tab.rawValue)-\(isCurrentTab(tab,store.route) ? "selected-white":"normal").svg",
          tint: isCurrentTab(tab, store.route) ? .white : Color(hex: 0xaaaab0)
        ).frame(width: 25, height: 25)
        if expanded {
          Text(tab == .community ? "发现" : tab.title).font(DS.font(14, weight: .bold))
          Spacer()
        }
      }.frame(maxWidth: .infinity, minHeight: 44).foregroundStyle(.white.opacity(0.8)).background(
        isCurrentTab(tab, store.route) ? Color(hex: 0x353538) : .clear,
        in: RoundedRectangle(cornerRadius: 14))
    }.buttonStyle(.plain).accessibilityLabel(tab.title).accessibilityIdentifier(
      "tab-" + tab.rawValue)
  }
}
struct AppOverlay: View {
  @Environment(AppStore.self) private var store
  let sheet: SheetRoute
  @State private var keyboardTop = CGFloat.greatestFiniteMagnitude
  private var title: String {
    switch sheet {
    case .chat: "问 AI"
    case .noteType: "记笔记"
    case .note: "核心概念"
    case .editChapter: "编辑章节"
    case .bookSwitcher: "切换课程"
    case .addMaterials: "添加资料"
    }
  }
  private var height: CGFloat {
    if store.isPad {
      return sheet == .chat
        ? 0
        : sheet == .noteType
          ? 534
          : sheet == .note ? 470 : sheet == .editChapter ? 969 : sheet == .bookSwitcher ? 593 : 500
    }
    return sheet == .chat
      ? 724
      : sheet == .noteType
        ? 582
        : sheet == .note ? 518 : sheet == .editChapter ? 766 : sheet == .bookSwitcher ? 697 : 534
  }
  var body: some View {
    GeometryReader { geometry in
      let visibleHeight = max(
        120, min(geometry.size.height, keyboardTop - geometry.frame(in: .global).minY))
      ZStack(alignment: store.isPad ? (sheet == .chat ? .topTrailing : .center) : .bottom) {
        Color(hex: 0x20263a).opacity(0.46).ignoresSafeArea().onTapGesture { store.closeSheet() }
          .accessibilityLabel("关闭弹层")
        VStack(spacing: 0) {
          if !store.isPad {
            Capsule().fill(Color(hex: 0xd2d0d8)).frame(width: 42, height: 5).padding(.top, 14)
              .padding(.bottom, 10)
          }
          HStack {
            Text(title).font(DS.font(20.8, weight: .bold))
            Spacer()
            Button {
              store.closeSheet()
            } label: {
              BCGlyph("X").frame(width: 18, height: 18).frame(width: 44, height: 44).background(
                .white, in: RoundedRectangle(cornerRadius: 12)
              ).overlay(RoundedRectangle(cornerRadius: 12).stroke(DS.border, lineWidth: 1))
            }.accessibilityLabel("关闭").accessibilityIdentifier("overlay-close")
          }.padding(.horizontal, store.isPad ? 32 : 16).frame(height: 52)
          Group {
            switch sheet {
            case .chat: AssistantChatView()
            case .note, .noteType: NoteSheetView(sheet: sheet)
            default:
              CourseSheetView(sheet: sheet).padding(
                .horizontal, sheet == .addMaterials ? 0 : store.isPad ? 32 : 16)
            }
          }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(
          width: store.isPad
            ? min(sheet == .chat ? 420 : 560, geometry.size.width - 48) : geometry.size.width,
          height: store.isPad && sheet == .chat
            ? max(120, visibleHeight - 33) : min(height, visibleHeight - 16)
        )
        .background(.white, in: RoundedRectangle(cornerRadius: 28)).compositingGroup().shadow(
          color: DS.text.opacity(0.22), radius: 30, y: 16
        )
        .padding(.trailing, store.isPad && sheet == .chat ? 32 : 0).padding(
          .top, store.isPad && sheet == .chat ? 13 : 0
        )
        .offset(
          x: store.isPad && sheet != .chat && store.route.showsPrimaryNavigation ? 34.17 : 0,
          y: store.isPad && sheet != .chat ? -4 : 0)
      }.frame(width: geometry.size.width, height: visibleHeight).accessibilityAddTraits(.isModal)
    }.ignoresSafeArea(.container, edges: .bottom)
      .onReceive(
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)
      ) { notification in
        keyboardTop =
          (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.minY
          ?? .greatestFiniteMagnitude
      }
      .onReceive(
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
      ) { _ in keyboardTop = .greatestFiniteMagnitude }
  }
}
struct FloatingAssistant: View {
  @Environment(AppStore.self) private var store
  var windowSize: CGSize
  var safeArea: EdgeInsets
  var navHeight: CGFloat
  var lessonEntry = false
  @Environment(\.bookCourseReduceMotion) private var reduceMotion
  @Binding var top: CGFloat?
  @Binding var left: Bool
  @GestureState private var translation = CGSize.zero
  private var pad: Bool { windowSize.width >= 720 && windowSize.height >= 600 }
  private var orbWidth: CGFloat { pad ? 68 : 62 }
  private var orbHeight: CGFloat { pad ? 79 : 72 }
  private var minTop: CGFloat { lessonEntry ? 122 : (pad ? 24 : safeArea.top) + 12 }
  private var maxTop: CGFloat {
    let bottom = pad ? 0 : safeArea.bottom
    let completion: CGFloat = lessonEntry && store.learningState.readerCompletionVisible ? 68 : 0
    return max(
      minTop,
      windowSize.height - bottom - navHeight - (lessonEntry ? 16 : 12) - orbHeight - completion)
  }
  private var initialTop: CGFloat {
    minTop + (maxTop - minTop) * (lessonEntry ? 0.56 : windowSize.height < 760 ? 0.69 : 0.82)
  }
  private var actualTop: CGFloat { min(maxTop, max(minTop, top ?? initialTop)) }
  var body: some View {
    GeometryReader { geometry in
      AssetImage(
        translation == .zero
          ? "/assets/brand/ai-assistant/idle-\(left ? "left":"right")-v1.png"
          : "/assets/brand/ai-assistant/dragging-v1.png"
      )
      .frame(width: orbWidth, height: orbHeight).contentShape(Circle())
      .offset(
        x: (left
          ? safeArea.leading
          : windowSize.width - safeArea.trailing - orbWidth + (lessonEntry ? 1 : 0))
          - geometry.frame(in: .global).minX + translation.width,
        y: actualTop - geometry.frame(in: .global).minY + translation.height
      )
      .onTapGesture { store.globalAssistantOpen = true }
      .gesture(
        DragGesture(minimumDistance: 8).updating($translation) { v, state, _ in
          state = v.translation
        }.onEnded { value in
          let base = left ? safeArea.leading : windowSize.width - safeArea.trailing - orbWidth
          withAnimation(reduceMotion ? nil : DS.globalAnimation) {
            left = base + value.translation.width + orbWidth / 2 < windowSize.width / 2
            top = min(maxTop, max(minTop, actualTop + value.translation.height))
          }
        }
      )
      .accessibilityLabel("打开学习助手").accessibilityIdentifier("assistant-entry")
      .accessibilityAddTraits(.isButton)
    }.onAppear {
      if top == nil {
        left = !lessonEntry && windowSize.height < 600 && windowSize.width > windowSize.height
        top = initialTop
      }
    }
    .onChange(of: windowSize) { _, _ in top = min(maxTop, max(minTop, actualTop)) }
  }
}
struct AssistantChatView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.bookCourseReduceMotion) private var reduceMotion
  @State private var question = ""
  @State private var inputError: String?
  @FocusState private var focused: Bool
  private var sourceChapterTitle: String {
    store.chapters.first { $0.id == store.selectedChapterID }?.source_title ?? store.chapterTitle
  }
  private var greeting: String {
    "你好！可以聊聊，也可以问“\(sourceChapterTitle)”。有可靠教材来源时会标出引用位置。"
  }
  private var courseLabelLineHeight: CGFloat {
    (UIFont(name: "BookCourseNotoSansSC-Bold", size: 20) ?? .boldSystemFont(ofSize: 20)).lineHeight
  }
  var body: some View {
    ScrollViewReader { proxy in
      GeometryReader { viewport in
        ScrollView {
          VStack(alignment: .leading, spacing: 14) {
            Text("剩余 \(store.credits) 积分 · 每次提问消耗 1 积分").font(DS.font(20)).foregroundStyle(
              DS.secondary
            ).frame(height: 28, alignment: .top)
            if store.currentSource != nil {
              Text("当前课程：《\(store.currentTitle)》").font(DS.font(20, weight: .bold)).foregroundStyle(
                Color(hex: 0x176caa)
              ).lineLimit(store.isPad ? nil : 1)
                .lineSpacing(28 - courseLabelLineHeight)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 11)
                .padding(.vertical, max(0, (40 - courseLabelLineHeight) / 2))
                .frame(minHeight: 40, maxHeight: store.isPad ? nil : 40)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: 0xe7f2fb), in: Capsule()).overlay(
                  Capsule().stroke(Color(hex: 0xbdddf4), lineWidth: 1))
            }
            if store.chatMessages.isEmpty {
              assistantLabel
              Text(greeting).font(DS.font(20)).lineSpacing(4).padding(.vertical, 2).padding(13)
                .frame(
                  maxWidth: .infinity, alignment: .leading
                ).background(.white, in: RoundedRectangle(cornerRadius: 18)).overlay(
                  RoundedRectangle(cornerRadius: 18).stroke(DS.border, lineWidth: 1)
                ).padding(.trailing, 29.6)
            }
            ForEach(store.chatMessages) { message in
              VStack(alignment: .leading, spacing: 12) {
                if message.role != "user" { assistantLabel }
                Text(message.text).font(DS.font(20)).lineSpacing(4).padding(.vertical, 2)
                  .textSelection(.enabled).padding(
                    12
                  ).frame(maxWidth: .infinity, alignment: .leading).background(
                    message.role == "user" ? DS.primarySoft : .white,
                    in: RoundedRectangle(cornerRadius: 18)
                  ).overlay(RoundedRectangle(cornerRadius: 18).stroke(DS.border, lineWidth: 1))
                ForEach(message.citations) { citation in
                  Button {
                    store.closeSheet()
                    store.openCitation(citation)
                  } label: {
                    VStack(alignment: .leading, spacing: 4) {
                      Text(citation.chapterTitle).font(DS.font(16, weight: .bold))
                      Text(
                        citation.printedPage.map { "教材第 \($0) 页 · PDF 第 \(citation.page) 页" }
                          ?? "PDF 第 \(citation.page) 页"
                      ).font(DS.font(14))
                      Text(citation.quote).font(DS.font(14)).lineLimit(2)
                    }.foregroundStyle(DS.primary).padding(12).frame(
                      maxWidth: .infinity, alignment: .leading
                    ).background(
                      DS.primarySoft.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                  }
                }
              }.id(message.id)
            }
            if store.chatLoading {
              HStack {
                ProgressView().tint(DS.primary)
                Text("正在查阅资料…").font(DS.font(14)).foregroundStyle(DS.secondary)
              }.id("loading")
            }
            if let inputError {
              Text(inputError).font(DS.font(14)).foregroundStyle(DS.secondary)
            }
            if !store.chatMessages.contains(where: { !$0.citations.isEmpty }) {
              Text("有可靠教材来源时会显示对应页码。").font(DS.font(14)).foregroundStyle(DS.secondary)
                .frame(height: 18.9, alignment: .top).padding(.vertical, 14)
            }
            HStack(spacing: 8) {
              ForEach(["举一个例子", "给我出一道题"], id: \.self) { prompt in
                Button {
                  send(
                    prompt == "举一个例子"
                      ? "请结合原文给一个\(sourceChapterTitle)的例子" : "围绕\(sourceChapterTitle)给我出一道题")
                } label: {
                  Text(prompt).font(DS.font(20)).padding(.horizontal, 12).frame(height: 44)
                    .background(DS.primarySoft, in: Capsule())
                }.foregroundStyle(DS.primary).disabled(store.chatLoading)
              }
            }
            VStack(alignment: .leading, spacing: 8) {
              Text("继续提问").font(DS.font(20, weight: .bold)).frame(height: 28, alignment: .top)
              TextField(
                "", text: $question, prompt: Text("围绕本章继续提问...").foregroundColor(DS.muted),
                axis: .vertical
              ).font(DS.font(20)).lineLimit(
                1...4
              ).padding(12).frame(minHeight: 54).background(
                .white, in: RoundedRectangle(cornerRadius: 18)
              ).overlay(
                RoundedRectangle(cornerRadius: 18).stroke(Color(hex: 0xd5e4fb), lineWidth: 1)
              )
              .focused($focused).onSubmit { send(question) }.submitLabel(.send)
              .accessibilityIdentifier("assistant-input")
            }
            BCButton(store.chatLoading ? "正在查阅资料…" : "发送问题") { send(question) }
              .disabled(store.chatLoading).accessibilityIdentifier("assistant-send").id(
                "assistant-composer")
          }.padding(.horizontal, store.isPad ? 32 : 16).padding(.top, 10).padding(
            .bottom, store.isPad ? 32 : 48)
        }
        .frame(width: viewport.size.width, height: viewport.size.height)
        .background(.white).contentShape(Rectangle()).clipped()
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: focused) { _, value in
          if value { revealComposer(proxy) }
        }
        .onChange(of: viewport.size.height) { _, _ in
          if focused { revealComposer(proxy) }
        }
        .onChange(of: question) { _, _ in
          if focused { revealComposer(proxy) }
        }
        .onReceive(
          NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)
        ) { _ in
          if focused { revealComposer(proxy) }
        }
        .onChange(of: store.chatMessages.count) { _, _ in
          if let id = store.chatMessages.last?.id {
            withAnimation(reduceMotion ? nil : DS.localAnimation) {
              proxy.scrollTo(id, anchor: .bottom)
            }
          }
        }
      }
    }
  }
  private func revealComposer(_ proxy: ScrollViewProxy) {
    Task { @MainActor in
      // Wait for the resized keyboard viewport to participate in layout. A
      // focus-only delay races UIKit's own field visibility adjustment.
      await Task.yield()
      proxy.scrollTo("assistant-composer", anchor: .bottom)
    }
  }
  private var assistantLabel: some View {
    Text("学习助手").font(DS.font(20, weight: .bold)).foregroundStyle(Color(hex: 0x176caa)).padding(
      .horizontal, 12
    ).frame(height: 40).background(Color(hex: 0xe7f2fb), in: Capsule()).overlay(
      Capsule().stroke(Color(hex: 0xbdddf4), lineWidth: 1))
  }
  private func send(_ text: String) {
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      inputError = "请输入要提问的问题。"
      return
    }
    inputError = nil
    question = ""
    Task { await store.ask(text) }
  }
}
