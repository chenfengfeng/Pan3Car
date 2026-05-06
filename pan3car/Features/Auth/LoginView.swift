//
//  LoginView.swift
//  pan3car
//
//  Created by Codex on 2026/5/4.
//

import SwiftUI

struct LoginView: View {
    @Environment(AppSession.self) private var session

    @State private var account = ""
    @State private var password = ""
    @State private var isFormPresented: Bool
    @State private var errorMessage: String?
    @State private var invalidFields: Set<LoginField> = []
    @State private var accountShakeTrigger = 0
    @State private var passwordShakeTrigger = 0
    @State private var validationFeedbackTrigger = 0
    @State private var isAuthenticating = false
    @FocusState private var focusedField: LoginField?

    private enum LoginField: Hashable {
        case account
        case password
    }

    init(isFormPresented: Bool = false) {
        _isFormPresented = State(initialValue: isFormPresented)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView {
                    loginContent(maxWidth: proxy.size.width, minHeight: proxy.size.height)
                }
            }
            .background(loginBackground)
            .safeAreaInset(edge: .bottom) {
                if !isFormPresented {
                    revealButton
                        .padding(.horizontal, 32)
                        .padding(.top, 16)
                        .padding(.bottom, 28)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .sensoryFeedback(.error, trigger: validationFeedbackTrigger)
        }
    }

    private var title: some View {
        Text("欢迎使用胖3助手")
            .font(.system(.largeTitle, design: .rounded, weight: .bold))
            .multilineTextAlignment(.center)
            .foregroundStyle(.primary)
            .accessibilityAddTraits(.isHeader)
    }

    private var loginBackground: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color(.systemGroupedBackground),
                Color.accentColor.opacity(0.08)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private func loginContent(maxWidth: CGFloat, minHeight: CGFloat) -> some View {
        let contentWidth = min(maxWidth - 48, 520)
        let horizontalCenter = maxWidth / 2
        let titleCenterY: CGFloat = isFormPresented ? 96 : 122
        let petCenterY: CGFloat = isFormPresented ? 300 : minHeight / 2
        let formCenterY: CGFloat = 475

        return ZStack {
            title
                .frame(width: contentWidth)
                .position(x: horizontalCenter, y: titleCenterY)

            petImage(maxWidth: maxWidth)
                .position(x: horizontalCenter, y: petCenterY)

            if isFormPresented {
                form
                    .frame(width: contentWidth)
                    .position(x: horizontalCenter, y: formCenterY)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: minHeight, alignment: .top)
        .animation(.snappy(duration: 0.36), value: isFormPresented)
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField = nil
        }
    }

    private func petImage(maxWidth: CGFloat) -> some View {
        Image(focusedField == .password ? "pet_nolook" : "pet_look")
            .resizable()
            .scaledToFit()
            .frame(width: min(maxWidth * 0.68, isFormPresented ? 260 : 286))
            .shadow(color: .black.opacity(0.08), radius: 18, y: 10)
            .accessibilityLabel("胖3助手宠物")
            .accessibilityIdentifier("login.petImage")
            .animation(.easeInOut(duration: 0.18), value: focusedField)
    }

    private var revealButton: some View {
        Button(action: revealForm) {
            glassButtonLabel("开始使用")
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("login.reveal")
    }

    private var form: some View {
        glassCard(cornerRadius: 30) {
            VStack(spacing: 18) {
                LabeledInputField(
                    title: "账号",
                    systemImage: "person.crop.circle.fill",
                    placeholder: "请输入账号",
                    text: $account,
                    isSecure: false,
                    isInvalid: invalidFields.contains(.account),
                    shakeTrigger: accountShakeTrigger
                )
                .textContentType(.username)
                .keyboardType(.numberPad)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: account) { _, _ in
                    let normalizedAccount = normalizedAccountInput(account)
                    if account != normalizedAccount {
                        account = normalizedAccount
                    }
                    clearValidation(for: .account)
                }
                .focused($focusedField, equals: .account)
                .submitLabel(.next)
                .onSubmit {
                    if !isAuthenticating {
                        focusedField = .password
                    }
                }
                .accessibilityIdentifier("login.account")
                .disabled(isAuthenticating)

                LabeledInputField(
                    title: "密码",
                    systemImage: "lock.fill",
                    placeholder: "请输入密码",
                    text: $password,
                    isSecure: true,
                    isInvalid: invalidFields.contains(.password),
                    shakeTrigger: passwordShakeTrigger
                )
                .textContentType(.password)
                .onChange(of: password) { _, _ in
                    clearValidation(for: .password)
                }
                .focused($focusedField, equals: .password)
                .submitLabel(.go)
                .onSubmit(submit)
                .accessibilityIdentifier("login.password")
                .disabled(isAuthenticating)

                errorMessageSlot

                submitButton
            }
            .padding(22)
        }
    }

    private var errorMessageSlot: some View {
        Label(errorMessage ?? "占位", systemImage: "exclamationmark.circle.fill")
            .font(.footnote.weight(.medium))
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
            .opacity(errorMessage == nil ? 0 : 1)
            .accessibilityHidden(errorMessage == nil)
            .accessibilityIdentifier("login.error")
    }

    private var submitButton: some View {
        Button(action: submit) {
            submitButtonContent
        }
        .buttonStyle(.plain)
        .disabled(isAuthenticating)
        .accessibilityLabel("登录胖3")
        .accessibilityIdentifier("login.submit")
    }

    @ViewBuilder
    private var submitButtonContent: some View {
        if isAuthenticating {
            glassLoadingLabel
                .transition(.scale.combined(with: .opacity))
        } else {
            glassButtonLabel("登录胖3")
                .transition(.scale.combined(with: .opacity))
        }
    }

    private func revealForm() {
        errorMessage = nil

        withAnimation(.snappy(duration: 0.36)) {
            isFormPresented = true
        }

        focusedField = .account
    }

    private func submit() {
        guard !isAuthenticating else {
            return
        }

        focusedField = nil

        let trimmedAccount = account.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedAccount.isEmpty else {
            markInvalid(.account, message: "请输入账号", shouldFocus: false)
            return
        }

        guard !trimmedPassword.isEmpty else {
            markInvalid(.password, message: "请输入密码", shouldFocus: false)
            return
        }

        errorMessage = nil
        invalidFields.removeAll()

        withAnimation(.snappy(duration: 0.28)) {
            isAuthenticating = true
        }

        Task {
            try? await Task.sleep(for: .seconds(2))

            guard !Task.isCancelled else {
                return
            }

            if password == "1234" {
                session.signInForPreview()
            } else {
                withAnimation(.snappy(duration: 0.28)) {
                    isAuthenticating = false
                }

                markInvalid(.password, message: "密码错误", shouldFocus: false)
            }
        }
    }

    private func markInvalid(_ field: LoginField, message: String, shouldFocus: Bool = true) {
        errorMessage = message
        invalidFields = [field]
        if shouldFocus {
            focusedField = field
        }
        validationFeedbackTrigger += 1

        withAnimation(.linear(duration: 0.34)) {
            switch field {
            case .account:
                accountShakeTrigger += 1
            case .password:
                passwordShakeTrigger += 1
            }
        }
    }

    private func clearValidation(for field: LoginField) {
        invalidFields.remove(field)

        if invalidFields.isEmpty {
            errorMessage = nil
        }
    }

    private func normalizedAccountInput(_ input: String) -> String {
        String(input.filter(\.isNumber).prefix(11))
    }

    @ViewBuilder
    private func glassButtonLabel(_ title: String) -> some View {
        let shape = Capsule(style: .continuous)

        Text(title)
            .font(.headline)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 58)
            .contentShape(shape)
            .modifier(GlassButtonSurface(shape: shape))
    }

    private var glassLoadingLabel: some View {
        let shape = Capsule(style: .continuous)

        return ProgressView()
            .controlSize(.regular)
            .tint(.primary)
            .frame(width: 58, height: 58)
            .contentShape(shape)
            .modifier(GlassButtonSurface(shape: shape))
    }

    @ViewBuilder
    private func glassCard<Content: View>(
        cornerRadius: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: 18) {
                content()
                    .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            content()
                .background(.thinMaterial, in: shape)
                .overlay {
                    shape.stroke(.primary.opacity(0.08), lineWidth: 1)
                }
        }
    }
}

private struct GlassButtonSurface<S: Shape>: ViewModifier {
    let shape: S

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(.regular.interactive(), in: shape)
        } else {
            content
                .background(.thinMaterial, in: shape)
                .overlay {
                    shape.stroke(.primary.opacity(0.12), lineWidth: 1)
                }
        }
    }
}

private struct LabeledInputField: View {
    let title: String
    let systemImage: String
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool
    let isInvalid: Bool
    let shakeTrigger: Int

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isInvalid ? Color.red : Color.secondary)

            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .font(.body)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.secondarySystemBackground).opacity(0.82), in: shape)
            .overlay {
                shape.stroke(isInvalid ? Color.red : Color.primary.opacity(0.08), lineWidth: isInvalid ? 1.5 : 1)
            }
            .modifier(ShakeEffect(trigger: shakeTrigger))
            .animation(.easeInOut(duration: 0.18), value: isInvalid)
        }
    }
}

private struct ShakeEffect: GeometryEffect {
    var travel: CGFloat
    var amount: CGFloat = 10
    var shakesPerUnit = 3

    init(trigger: Int) {
        travel = CGFloat(trigger)
    }

    var animatableData: CGFloat {
        get { travel }
        set { travel = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(
                translationX: amount * sin(travel * .pi * CGFloat(shakesPerUnit)),
                y: 0
            )
        )
    }
}

#Preview("Login Light") {
    LoginView()
        .environment(AppSession())
}

#Preview("Login Dark") {
    LoginView()
        .environment(AppSession())
        .preferredColorScheme(.dark)
}

#Preview("Login Form") {
    LoginView(isFormPresented: true)
        .environment(AppSession())
}
