import SwiftUI

struct AutomationView: View {
    var notify: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("치이카와 · 자동화 검수").font(.system(size: 25, weight: .bold, design: .rounded))
                    Text("자동화가 잘 동작하는지 함께 확인해요.").foregroundColor(.secondary)
                }
                Spacer()
                Button("테스트 알림", action: notify)
            }
            HStack(spacing: 8) {
                Circle().fill(Color.gray.opacity(0.5)).frame(width: 7, height: 7)
                Text("Monday 미연결").font(.system(size: 12)).foregroundColor(.secondary)
            }
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "checkmark.shield").font(.system(size: 30)).foregroundColor(.pink.opacity(0.6))
                Text("자동화 검수와 오류 알림을 준비하고 있어요").font(.headline)
                Text("Monday 연결 후 검수할 자동화와 오류 알림이 여기에 모여요.\nBOM 등록·변경 업무는 하치와레가 맡아요.")
                    .foregroundColor(.secondary).lineSpacing(5)
            }.padding(26).frame(maxWidth: .infinity, alignment: .leading).background(Color.white).cornerRadius(18)
            Spacer()
            Text("무서워도 하나씩, 끝까지 확인할게요 ♡").font(.system(size: 12)).foregroundColor(.secondary)
        }.padding(30).frame(minWidth: 700, minHeight: 470)
            .background(Color(red: 0.98, green: 0.96, blue: 0.95)).preferredColorScheme(.light)
    }
}
