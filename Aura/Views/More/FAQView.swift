import SwiftUI

// MARK: - FAQ Item Model

struct FAQItem: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
    let icon: String
    let gradient: [Color]
    let tags: [String]
}

struct FAQCategory: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let gradient: [Color]
    let items: [FAQItem]
}

// MARK: - FAQ View

struct FAQView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var expandedItems: Set<UUID> = []

    private let categories: [FAQCategory] = [
        FAQCategory(
            title: "Friday AI Ассистент",
            subtitle: "Голос, текст, авто-действия и интернет",
            icon: "sparkles",
            gradient: [Color(hex: "667eea"), Color(hex: "764ba2")],
            items: [
                FAQItem(
                    question: "Как Friday сам создает задачи из чата?",
                    answer: "Просто напишите ассистенту просьбу в свободной форме, например:\n• «Напомни завтра в 14:00 созвониться с врачом»\n• «Создай срочную задачу подготовить отчет до пятницы»\n\nFriday сам распознает дату, время, приоритет и создаст задачу во вкладке «Задачи», а также запланирует системное напоминание.",
                    icon: "checkmark.circle.fill",
                    gradient: AppGradients.purple,
                    tags: ["ai", "задачи", "напоминания", "friday"]
                ),
                FAQItem(
                    question: "Как быстро записывать расходы и доходы?",
                    answer: "Напишите Friday в чате:\n• «Запиши расход 2500 тг на такси»\n• «Добавь доход 350 000 тг зарплата»\n• «Потратил 4200 тг в супермаркете»\n\nАссистент определит сумму, категорию и создаст запись во вкладке «Финансы». В чате появится карточка подтверждения.",
                    icon: "creditcard.fill",
                    gradient: [Color(hex: "fa709a"), Color(hex: "fee140")],
                    tags: ["ai", "финансы", "расходы", "доходы"]
                ),
                FAQItem(
                    question: "Как работает поиск в интернете (Web Search)?",
                    answer: "Если настроен бесплатный ключ Serper API (в Настройках), Friday автоматически ищет свежую информацию в Google:\n• Курсы валют (тенге, доллар, евро)\n• Актуальную погоду в любом городе\n• Последние новости и факты\n\nВам не нужно открывать браузер — ответ будет прямо в диалоге.",
                    icon: "magnifyingglass",
                    gradient: [Color(hex: "11998e"), Color(hex: "38ef7d")],
                    tags: ["поиск", "serper", "google", "интернет", "погода"]
                ),
                FAQItem(
                    question: "Что такое Вечерняя сводка?",
                    answer: "В верхнем меню чата нажмите «Вечерняя сводка» или попросите ассистента: «Подведи итоги дня». Friday проанализирует выполненные задачи, оставшиеся дела и траты за сегодня и подготовит лаконичный персональный отчет.",
                    icon: "moon.stars.fill",
                    gradient: [Color(hex: "f093fb"), Color(hex: "f5576c")],
                    tags: ["сводка", "итоги", "анализ"]
                )
            ]
        ),
        FAQCategory(
            title: "Задачи и Планирование",
            subtitle: "Фильтры, приоритеты и дедлайны",
            icon: "checklist",
            gradient: [Color(hex: "4facfe"), Color(hex: "00f2fe")],
            items: [
                FAQItem(
                    question: "Как работает фильтрация задач по датам?",
                    answer: "На экране «Задачи» вверху доступен фильтр:\n• «Все» — полный список ваших задач\n• «Сегодня» — задачи с дедлайном на сегодня\n• «Неделя» — задачи на ближайшие 7 дней\n• «Месяц» — дела на текущий месяц\n• «Просрочено» — задачи, требующие срочного внимания\n• Кнопка календаря — выбор любой точной даты",
                    icon: "calendar",
                    gradient: [Color(hex: "4facfe"), Color(hex: "00f2fe")],
                    tags: ["задачи", "фильтры", "даты", "календарь"]
                ),
                FAQItem(
                    question: "Как настроить напоминания?",
                    answer: "При создании задачи включите тумблер даты и времени. Приложение автоматически запросит разрешение на отправку push-уведомлений и пришлет сигнал ровно в указанный срок.",
                    icon: "bell.fill",
                    gradient: AppGradients.orange,
                    tags: ["напоминания", "уведомления"]
                )
            ]
        ),
        FAQCategory(
            title: "Финансы и Бюджет",
            subtitle: "Учет, графики и SMS банков",
            icon: "chart.pie.fill",
            gradient: [Color(hex: "43e97b"), Color(hex: "38f9d7")],
            items: [
                FAQItem(
                    question: "Как работает автоматическое распознавание SMS банков?",
                    answer: "Friday умеет автоматически определять чеки и траты из SMS казахстанских банков (Kaspi, Halyk, Jusan и др.).\nВ Настройках включите «Парсинг банковских уведомлений». Вы также можете вставить текст любого SMS во вкладке «Финансы», и система за секунду распознает сумму, магазин и категорию.",
                    icon: "message.fill",
                    gradient: AppGradients.green,
                    tags: ["банк", "kaspi", "halyk", "sms", "чеки"]
                ),
                FAQItem(
                    question: "Где хранятся мои финансовые данные?",
                    answer: "Все финансовые записи, доходы и расходы хранятся локально на вашем iPhone в защищенной базе SwiftData. Никакие ваши транзакции не отправляются сторонним серверам без вашего ведома.",
                    icon: "lock.shield.fill",
                    gradient: [Color(hex: "667eea"), Color(hex: "764ba2")],
                    tags: ["безопасность", "приватность", "хранение"]
                )
            ]
        ),
        FAQCategory(
            title: "Календарь и Праздники",
            subtitle: "Интеграция с Apple Calendar и праздники РК",
            icon: "calendar.badge.clock",
            gradient: [Color(hex: "5ee7df"), Color(hex: "b490ca")],
            items: [
                FAQItem(
                    question: "Как переключать праздники Казахстана?",
                    answer: "Во вкладке «Календарь» нажмите на значок фильтра праздников. Доступны официальные государственные праздники РК (Наурыз, День Республики, День Независимости и др.) с подсветкой дат.",
                    icon: "flag.fill",
                    gradient: [Color(hex: "5ee7df"), Color(hex: "b490ca")],
                    tags: ["календарь", "казахстан", "праздники"]
                ),
                FAQItem(
                    question: "Синхронизируются ли события с Apple Calendar?",
                    answer: "Да. При первом входе в календарь предоставьте доступ к EventKit. Ваши системные календари и события сразу появятся в расписании.",
                    icon: "link",
                    gradient: AppGradients.blue,
                    tags: ["календарь", "apple", "eventkit"]
                )
            ]
        ),
        FAQCategory(
            title: "Настройка интерфейса и вкладок",
            subtitle: "Кастомизация под ваш стиль",
            icon: "slider.horizontal.3",
            gradient: [Color(hex: "fa709a"), Color(hex: "fee140")],
            items: [
                FAQItem(
                    question: "Как настроить нижнюю панель вкладок?",
                    answer: "Перейдите во вкладку «Ещё» и нажмите кнопку «Настроить» вверху (или пункт «Настройка панели вкладок»). Вы можете выбрать до 3 главных вкладок (например, Задачи, Friday AI, Финансы), менять их порядок перетаскиванием, а остальные разделы будут доступны во вкладке «Ещё».",
                    icon: "square.grid.2x2",
                    gradient: AppGradients.orange,
                    tags: ["вкладки", "панель", "интерфейс"]
                ),
                FAQItem(
                    question: "Как включить темную или светлую тему?",
                    answer: "Перейдите в «Ещё» → «Настройки» → блок «Внешний вид» и выберите предпочтительную тему: Темная или Светлая.",
                    icon: "paintpalette.fill",
                    gradient: AppGradients.purple,
                    tags: ["тема", "темная", "светлая", "дизайн"]
                )
            ]
        )
    ]

    private var filteredCategories: [FAQCategory] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return categories }

        return categories.compactMap { cat in
            let matchingItems = cat.items.filter { item in
                item.question.lowercased().contains(q) ||
                item.answer.lowercased().contains(q) ||
                item.tags.contains { $0.lowercased().contains(q) }
            }
            if matchingItems.isEmpty { return nil }
            return FAQCategory(
                title: cat.title,
                subtitle: cat.subtitle,
                icon: cat.icon,
                gradient: cat.gradient,
                items: matchingItems
            )
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Banner
                    headerBanner

                    // Search Bar
                    searchBar

                    // FAQ Categories
                    if filteredCategories.isEmpty {
                        emptyState
                    } else {
                        ForEach(filteredCategories) { category in
                            categorySection(category)
                        }
                    }

                    // Contact / Support Footer
                    supportFooter
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .background(AppColors.appBackground.ignoresSafeArea())
            .navigationTitle("Инструкция и FAQ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color(hex: "667eea"))
                }
            }
        }
    }

    // MARK: - Header Banner

    private var headerBanner: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)

                Image(systemName: "questionmark")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Как устроен Friday")
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)

                Text("Полное руководство по умному ассистенту, планированию и финансам.")
                    .font(.caption)
                    .foregroundStyle(AppColors.textPrimary.opacity(0.6))
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(16)
        .background(AppColors.textPrimary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppColors.textPrimary.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(AppColors.textPrimary.opacity(0.4))

            TextField("Поиск по инструкции...", text: $searchText)
                .font(.subheadline)
                .foregroundStyle(AppColors.textPrimary)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.textPrimary.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(AppColors.textPrimary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Category Section

    private func categorySection(_ category: FAQCategory) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(colors: category.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(category.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)
                    Text(category.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.textPrimary.opacity(0.45))
                }
            }
            .padding(.horizontal, 4)

            VStack(spacing: 8) {
                ForEach(category.items) { item in
                    faqItemRow(item)
                }
            }
        }
    }

    // MARK: - FAQ Item Row

    private func faqItemRow(_ item: FAQItem) -> some View {
        let isExpanded = expandedItems.contains(item.id)

        return VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    if isExpanded {
                        expandedItems.remove(item.id)
                    } else {
                        expandedItems.insert(item.id)
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(LinearGradient(colors: item.gradient, startPoint: .topLeading, endPoint: .bottomTrailing).opacity(0.15))
                            .frame(width: 28, height: 28)

                        Image(systemName: item.icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(item.gradient.first ?? Color.accentColor)
                    }

                    Text(item.question)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 8)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary.opacity(0.4))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(item.answer)
                    .font(.system(size: 13))
                    .lineSpacing(4)
                    .foregroundStyle(AppColors.textPrimary.opacity(0.75))
                    .padding(.top, 4)
                    .padding(.leading, 40)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background(AppColors.textPrimary.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppColors.textPrimary.opacity(0.05), lineWidth: 1)
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(AppColors.textPrimary.opacity(0.3))
                .padding(.top, 30)

            Text("Ничего не найдено")
                .font(.headline)
                .foregroundStyle(AppColors.textPrimary)

            Text("Попробуйте изменить поисковый запрос.")
                .font(.subheadline)
                .foregroundStyle(AppColors.textPrimary.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Support Footer

    private var supportFooter: some View {
        VStack(spacing: 6) {
            Text("Friday AI · Версия 1.0")
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppColors.textPrimary.opacity(0.35))
            Text("Создано для продуктивности и удобства")
                .font(.caption2)
                .foregroundStyle(AppColors.textPrimary.opacity(0.25))
        }
        .padding(.top, 16)
    }
}

