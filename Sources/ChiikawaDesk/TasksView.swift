import SwiftUI
import AppKit

private struct TaskCardData: Identifiable {
    let id: String
    let title: String
    let change: Bool
    let note: String
    let date: String
    let urgency: String
    var localID: UUID? = nil
    var state: WorkState = .inbox
}

struct TasksView: View {
    @ObservedObject var store: WorkStore
    var notify: () -> Void
    @State private var examples = true
    @State private var completedOpen = false
    @State private var adding = false
    @State private var title = ""
    @State private var kind = "BOM 등록"
    private let ink = Color(red: 0.25, green: 0.22, blue: 0.22)
    private let rose = Color(red: 0.76, green: 0.36, blue: 0.44)
    private let muted = Color(red: 0.55, green: 0.51, blue: 0.50)
    private let cream = Color(red: 0.98, green: 0.97, blue: 0.95)
    private var sampleInbox: [TaskCardData] { [
        .init(id: "i1", title: "신규 부품 BOM 등록 요청", change: false, note: "방금 도착 · 생산기술팀", date: "요청일 10.27", urgency: "D−7"),
        .init(id: "i2", title: "패키지 구성 수량 변경", change: true, note: "12분 전 · 제품개발팀", date: "요청일 10.25", urgency: "D−5")
    ] }
    private var sampleTodo: [TaskCardData] { [
        .init(id: "t1", title: "제어 모듈 BOM 변경", change: true, note: "나중에 진행 → 해야 할 것", date: "요청일 10.21", urgency: "D−1"),
        .init(id: "t2", title: "신규 모델 하위 부품 등록", change: false, note: "요청일까지 3일 남았어요", date: "요청일 10.23", urgency: "D−3")
    ] }
    private var sampleLater: [TaskCardData] { [
        .init(id: "l1", title: "커넥터 대체품 BOM 변경", change: true, note: "확인 후 나중에 진행으로 표시", date: "요청일 10.24", urgency: "D−4"),
        .init(id: "l2", title: "다음 생산분 BOM 등록", change: false, note: "확인 후 나중에 진행으로 표시", date: "요청일 10.30", urgency: "D−10"),
        .init(id: "l3", title: "예비 부품 구성 검토", change: true, note: "일정이 정해지면 챙겨요", date: "요청일 미정", urgency: "")
    ] }
    private var sampleDone: [TaskCardData] { [
        .init(id: "d1", title: "센서 어셈블리 BOM 등록", change: false, note: "오늘 10:42 완료", date: "10.20 완료", urgency: ""),
        .init(id: "d2", title: "포장 자재 사양 변경", change: true, note: "어제 16:20 완료", date: "10.19 완료", urgency: "")
    ] }
    private func local(_ state: WorkState) -> [TaskCardData] {
        store.items.filter { $0.state == state }.map {
            .init(id: $0.id.uuidString, title: $0.title, change: $0.kind.contains("변경"), note: "이 Mac에 저장한 업무", date: "요청일 미정", urgency: "", localID: $0.id, state: $0.state)
        }
    }
    private var inbox: [TaskCardData] { examples ? sampleInbox : local(.inbox) }
    private var todo: [TaskCardData] { examples ? sampleTodo : [] }
    private var later: [TaskCardData] { examples ? sampleLater : local(.later) }
    private var done: [TaskCardData] { examples ? sampleDone : local(.done) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Rectangle().fill(ink.opacity(0.07)).frame(height: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("오늘도 하나씩, 차근차근").font(.system(size: 22, weight: .bold, design: .rounded))
                            Text("새로 온 요청부터, 날짜가 가까운 업무까지 함께 챙겨요.")
                                .font(.system(size: 12)).foregroundColor(muted)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 5) {
                            Text(examples ? "10월 20일 화요일" : Date().formatted(.dateTime.month().day().weekday(.wide)))
                                .font(.system(size: 12, weight: .medium)).foregroundColor(muted)
                            Text("등록").font(.system(size: 10, weight: .semibold)).foregroundColor(Color(red: 0.25, green: 0.49, blue: 0.44))
                                + Text("  ·  ").font(.system(size: 10)).foregroundColor(muted)
                                + Text("변경").font(.system(size: 10, weight: .semibold)).foregroundColor(rose)
                        }
                    }
                    HStack(spacing: 10) {
                        Image(systemName: "sparkle").foregroundColor(rose)
                        Text(examples ? "디자인 미리보기" : "내 업무").font(.system(size: 11, weight: .semibold))
                        Text(examples ? "예시 업무예요. Monday 연결 후 실제 요청이 이곳에 모여요." : "이 Mac에 저장된 업무예요. Monday는 아직 연결 전이에요.")
                            .font(.system(size: 11)).foregroundColor(muted)
                        Spacer(minLength: 0)
                        Button(examples ? "저장된 업무 보기" : "디자인 예시 보기") { examples.toggle() }
                            .font(.system(size: 10, weight: .medium)).buttonStyle(.plain).foregroundColor(rose)
                    }.padding(12).background(Color.white.opacity(0.75)).cornerRadius(12)
                    HStack(alignment: .top, spacing: 14) {
                        column("알림", subtitle: "새로 도착한 요청", icon: "bell", items: inbox, accent: rose, footer: "새 요청이 들어오면 여기에 쌓여요")
                        column("해야 할 것", subtitle: "요청일까지 3일 이내", icon: "sun.max", items: todo, accent: Color(red: 0.70, green: 0.47, blue: 0.22), footer: "미뤄둔 업무도 날짜가 가까워지면 여기로")
                        column("나중에 진행할 것", subtitle: "가까운 요청일 순으로", icon: "bookmark", items: later, accent: Color(red: 0.40, green: 0.49, blue: 0.44), footer: "요청일이 없는 업무는 맨 아래에")
                    }
                    VStack(spacing: 0) {
                        Button { withAnimation(.easeInOut(duration: 0.2)) { completedOpen.toggle() } } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.circle").foregroundColor(Color(red: 0.40, green: 0.49, blue: 0.44))
                                Text("완료").font(.system(size: 13, weight: .semibold))
                                Text("\(done.count)").font(.system(size: 11, weight: .medium)).foregroundColor(muted)
                                Text("수고했어요. 끝낸 업무는 여기에 모아둘게요.").font(.system(size: 11)).foregroundColor(muted)
                                Spacer()
                                Text(completedOpen ? "접기" : "펼쳐 보기").font(.system(size: 11)).foregroundColor(muted)
                                Image(systemName: completedOpen ? "chevron.up" : "chevron.down").font(.system(size: 10)).foregroundColor(muted)
                            }.padding(16).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        if completedOpen {
                            VStack(spacing: 8) {
                                HStack { Text("최근 완료한 순서").font(.system(size: 10)).foregroundColor(muted); Spacer() }
                                ForEach(done) { item in card(item, completed: true) }
                                if done.isEmpty { Text("아직 완료한 업무가 없어요").font(.system(size: 12)).foregroundColor(muted).padding() }
                            }.padding([.horizontal, .bottom], 16)
                        }
                    }.background(Color.white.opacity(0.7)).cornerRadius(14)
                    HStack {
                        Text("하치와레가 옆에서 함께할게요 ♡").font(.system(size: 11)).foregroundColor(muted)
                        Spacer()
                        Text("Monday 연결 예정").font(.system(size: 10)).foregroundColor(muted)
                    }
                    if let error = store.storageError { Text(error).font(.caption).foregroundColor(.red) }
                }.padding(26)
            }
        }.foregroundColor(ink).background(cream).frame(minWidth: 1000, minHeight: 700)
            .preferredColorScheme(.light)
    }
    private var header: some View {
        HStack(spacing: 12) {
            if let url = Bundle.main.url(forResource: "Hachiware Walk", withExtension: "gif", subdirectory: "Resources"), let image = NSImage(contentsOf: url) {
                Image(nsImage: image).resizable().scaledToFit().frame(width: 40, height: 40)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("하치와레 BOM 친구").font(.system(size: 15, weight: .bold, design: .rounded))
                Text("BOM WORKSPACE").font(.system(size: 8, weight: .semibold)).tracking(2).foregroundColor(muted)
            }
            Spacer()
            HStack(spacing: 6) {
                Circle().fill(Color(red: 0.76, green: 0.72, blue: 0.67)).frame(width: 5, height: 5)
                Text("Monday 미연결").font(.system(size: 11)).foregroundColor(muted)
            }.padding(.horizontal, 11).padding(.vertical, 8).background(Color.white).cornerRadius(20)
            Button { adding = true } label: { Label("직접 추가", systemImage: "plus").font(.system(size: 11)) }
                .buttonStyle(.borderless).foregroundColor(muted)
                .popover(isPresented: $adding) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("업무 직접 추가").font(.headline)
                        Picker("종류", selection: $kind) { Text("등록").tag("BOM 등록"); Text("변경").tag("BOM 변경") }.pickerStyle(.segmented)
                        TextField("챙길 업무를 적어주세요", text: $title).onSubmit(add)
                        Button("추가", action: add).disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }.padding(20).frame(width: 280)
                }
            Button(action: notify) { Image(systemName: "bell.badge").font(.system(size: 14)) }.buttonStyle(.plain).foregroundColor(rose).help("테스트 알림")
        }.padding(.horizontal, 26).padding(.vertical, 16).background(Color.white.opacity(0.5))
    }
    private func column(_ name: String, subtitle: String, icon: String, items: [TaskCardData], accent: Color, footer: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 7) {
                Image(systemName: icon).font(.system(size: 13)).foregroundColor(accent)
                Text(name).font(.system(size: 13, weight: .bold))
                Text("\(items.count)").font(.system(size: 10, weight: .semibold)).foregroundColor(accent)
                    .padding(.horizontal, 7).padding(.vertical, 3).background(accent.opacity(0.09)).cornerRadius(8)
                Spacer(minLength: 0)
            }
            Text(subtitle).font(.system(size: 10)).foregroundColor(muted).padding(.top, -8)
            VStack(spacing: 10) {
                ForEach(items) { item in card(item) }
                if items.isEmpty { Text("아직 업무가 없어요").font(.system(size: 12)).foregroundColor(muted).frame(maxWidth: .infinity).padding(.vertical, 38) }
            }
            Spacer(minLength: 0)
            Text(footer).font(.system(size: 9)).foregroundColor(muted).fixedSize(horizontal: false, vertical: true)
        }.padding(14).frame(maxWidth: .infinity, minHeight: 400, alignment: .topLeading)
            .background(accent.opacity(0.045)).cornerRadius(16)
    }
    private func card(_ item: TaskCardData, completed: Bool = false) -> some View {
        let badge = item.change ? rose : Color(red: 0.25, green: 0.49, blue: 0.44)
        let urgent = item.urgency == "D−1" || item.urgency == "D−3"
        return VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text(item.change ? "변경" : "등록").font(.system(size: 9, weight: .bold)).foregroundColor(badge)
                    .padding(.horizontal, 7).padding(.vertical, 4).background(badge.opacity(0.10)).cornerRadius(5)
                Spacer()
                if !item.urgency.isEmpty {
                    Text(item.urgency).font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(urgent ? rose : muted)
                }
            }
            Text(item.title).font(.system(size: 12, weight: .semibold)).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            Text(item.note).font(.system(size: 9)).foregroundColor(muted).lineLimit(2)
            Rectangle().fill(ink.opacity(0.05)).frame(height: 1)
            HStack(spacing: 4) {
                Image(systemName: completed ? "checkmark" : "calendar").font(.system(size: 9))
                Text(item.date).font(.system(size: 10))
                Spacer(minLength: 0)
                if let id = item.localID {
                    Menu {
                        ForEach(WorkState.allCases, id: \.self) { state in
                            Button(state == .inbox ? "알림" : state.rawValue) { if let i = store.items.firstIndex(where: { $0.id == id }) { store.items[i].state = state } }
                        }
                    } label: { Image(systemName: "ellipsis").font(.system(size: 11)) }.menuStyle(.borderlessButton).frame(width: 20)
                }
            }.foregroundColor(muted)
        }.padding(13).frame(maxWidth: .infinity, alignment: .leading).background(Color.white)
            .cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(ink.opacity(0.045), lineWidth: 1))
    }
    private func add() {
        let value = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        store.items.append(WorkItem(title: value, kind: kind)); title = ""; adding = false; examples = false
    }
}
