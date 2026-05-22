import SwiftUI

/// Shared layout metrics so every Settings block lines up the same way.
enum SettingsSectionLayout {
    static let iconWidth: CGFloat = 32
    static let headerSpacing: CGFloat = 12
    static var contentInset: CGFloat { iconWidth + headerSpacing }
}

/// Section with icon + title row, then content indented to align with the title.
struct SettingsSection<Trailing: View, Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var content: () -> Content

    init(
        icon: String,
        iconColor: Color = .accentColor,
        title: String,
        subtitle: String,
        @ViewBuilder trailing: @escaping () -> Trailing,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: SettingsSectionLayout.headerSpacing) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(iconColor)
                    .frame(
                        width: SettingsSectionLayout.iconWidth,
                        height: SettingsSectionLayout.iconWidth,
                        alignment: .center
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)
                trailing()
            }

            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding(.leading, SettingsSectionLayout.contentInset)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

extension SettingsSection where Trailing == EmptyView {
    init(
        icon: String,
        iconColor: Color = .accentColor,
        title: String,
        subtitle: String,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            icon: icon,
            iconColor: iconColor,
            title: title,
            subtitle: subtitle,
            trailing: { EmptyView() },
            content: content
        )
    }
}

/// Page title row using the same icon column as sections below.
struct SettingsPageHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: SettingsSectionLayout.headerSpacing) {
            Image(systemName: "gearshape.fill")
                .font(.title2)
                .foregroundColor(.secondary)
                .frame(
                    width: SettingsSectionLayout.iconWidth,
                    height: SettingsSectionLayout.iconWidth,
                    alignment: .center
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title)
                    .fontWeight(.bold)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
