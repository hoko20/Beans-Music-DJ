import SwiftUI

// MARK: - 首次启动（单页引导 + 免责确认）

struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var typed = ""

    private let confirmText = "我已了解并同意"

    private var accepted: Bool { typed == confirmText }

    var body: some View {
        ZStack {
            Color.beansBackground.ignoresSafeArea()
            LinearGradient(
                colors: [Color.clear, Color.beansHighlight.opacity(0.14), Color.clear],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    Image("OnboardingLogo")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 104, height: 104)
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .shadow(color: Color.beansHighlight.opacity(0.4), radius: 22, y: 10)
                        .padding(.top, 48)

                    VStack(spacing: 6) {
                        Text("欢迎使用 DJ多多版")
                            .font(BeansFont.appFont(26, .bold))
                            .foregroundStyle(Color.beansLabel)
                        Text("歌曲、分类、音质来自 DJ多多公开接口")
                            .font(BeansFont.appFont(12))
                            .foregroundStyle(Color.beansSecondary)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        bullet("收藏、歌单、下载全部保存在本机")
                        bullet("无账号体系，不采集任何个人信息")
                        bullet("四档音质：流畅 / 标准 / 高品 / 无损")
                        bullet("仅供个人学习与自用，请勿传播")
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.beansCard.opacity(0.8))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.beansHighlight.opacity(0.2), lineWidth: 1)
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("输入「\(confirmText)」继续")
                            .font(BeansFont.appFont(12))
                            .foregroundStyle(Color.beansHighlight)
                        HStack(spacing: 10) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.beansHighlight)
                            TextField(confirmText, text: $typed)
                                .font(BeansFont.appFont(14))
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                            if !accepted {
                                Button("填入") { typed = confirmText }
                                    .font(BeansFont.appFont(11, .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .frame(height: 28)
                                    .background(Capsule().fill(LinearGradient.beansAccent))
                                    .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(Color.beansCard.opacity(0.85))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .strokeBorder(Color.beansHighlight.opacity(typed.isEmpty ? 0.25 : 0.7),
                                              lineWidth: 1.1)
                        )
                    }

                    Button {
                        onFinish()
                    } label: {
                        Text("进入应用")
                            .font(BeansFont.appFont(16, .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 17, style: .continuous)
                                    .fill(accepted ? Color.beansHighlight : Color.beansHighlight.opacity(0.32))
                            )
                    }
                    .disabled(!accepted)
                    .padding(.bottom, 40)
                }
                .padding(.horizontal, 24)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(Color.beansSage)
                .padding(.top, 1)
            Text(text)
                .font(BeansFont.appFont(13))
                .foregroundStyle(Color.beansLabel)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}