import SwiftUI

struct ScheduleView: View {
    var notify: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("우사기 · 회의·개인 일정").font(.system(size: 25, weight: .bold, design: .rounded))
                    Text("다가오는 일정은 우사기가 챙길게요!").foregroundColor(.secondary)
                }
                Spacer()
                Button("테스트 알림", action: notify)
            }
            HStack(spacing: 8) {
                Circle().fill(Color.gray.opacity(0.5)).frame(width: 7, height: 7)
                Text("캘린더 연결 전").font(.system(size: 12)).foregroundColor(.secondary)
            }
            HStack(alignment: .top, spacing: 16) {
                placeholder("회의 일정", icon: "person.2", text: "함께하는 약속을 여기에 모아요.")
                placeholder("개인 일정", icon: "calendar", text: "내가 챙길 약속을 여기에 모아요.")
            }
            Spacer()
            Text("이야아아아하!!!!!!!").font(.system(size: 16, weight: .bold)).foregroundColor(.orange)
            Text("일정 연결과 실제 자동 알림은 준비 중이에요. 지금은 테스트 알림으로 동작을 확인할 수 있어요.")
                .font(.system(size: 11)).foregroundColor(.secondary)
        }.padding(30).frame(minWidth: 740, minHeight: 480)
            .background(Color(red: 0.99, green: 0.98, blue: 0.93)).preferredColorScheme(.light)
    }
    private func placeholder(_ title: String, icon: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon).font(.headline)
            Text("아직 연결된 일정이 없어요").font(.system(size: 13))
            Text(text).font(.system(size: 12)).foregroundColor(.secondary)
        }.padding(24).frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading).background(Color.white).cornerRadius(18)
    }
}
