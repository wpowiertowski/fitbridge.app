// HealthKitUnavailableView.swift
//
// WP-10 (implementation-plan.md step 1): the explicit HealthKit-unavailable
// state ("HKHealthStore.isHealthDataAvailable() false, e.g. iPad"). A
// terminal, informational screen -- FitBridge's entire premise is writing
// into Apple Health, so there is no meaningful "continue anyway" path.
// `project.yml` restricts P0's `TARGETED_DEVICE_FAMILY` to iPhone only, so
// this state is not reachable from the App Store build today, but the
// WP-06/WP-10 briefs both require it to exist and degrade gracefully rather
// than crash or hang on a silent spinner if it ever is.

import SwiftUI

struct HealthKitUnavailableView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "xmark.octagon.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)
            Text("Apple Health Isn't Available")
                .font(.title.bold())
            Text("This device doesn't support Apple Health, so FitBridge can't import your Fitbit or Pixel Watch data here. Try FitBridge on a compatible iPhone.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .padding()
        .accessibilityIdentifier("onboarding.healthKitUnavailable")
    }
}

#Preview {
    HealthKitUnavailableView()
}
