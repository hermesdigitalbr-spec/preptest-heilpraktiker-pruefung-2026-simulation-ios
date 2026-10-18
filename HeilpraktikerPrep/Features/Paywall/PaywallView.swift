import SwiftUI

/// O paywall aberto de dentro do app é o MESMO do fim do onboarding: mesmo
/// carrossel, mesmos planos, mesma oferta de saída semanal. Antes eram duas
/// telas diferentes (esta era clara, com lista de benefícios e timeline), e
/// quem batia num limite via um paywall que não parecia o do funil.
///
/// As diferenças são duas: aqui a tela é modal e tem X, e o plano semanal da
/// oferta de saída não aparece — ele é a última chance do funil de onboarding,
/// não um plano do catálogo. Recusar dentro do app simplesmente fecha.
struct PaywallView: View {
    /// De onde o paywall foi aberto. Hoje não muda a tela — ficou aqui porque
    /// as chamadas existentes passam o valor e ele volta a ser útil caso a
    /// copy por gatilho seja reintroduzida no primeiro slide.
    enum Source {
        case generic, dailyCapHit, quickCapHit, studyLocked
    }

    var source: Source = .generic

    var body: some View {
        OnboardingPaywallView(showsCloseButton: true, offersWeeklyExit: false)
    }
}
