import CookbookCore

struct RecipesActiveFilters: Equatable, Sendable {
    var selectedTags: Set<String> = []
    var maxCookTimeMinutes: Int? = nil
    var maxPrepTimeMinutes: Int? = nil
    var difficulty: String? = nil
    var course: String? = nil

    /// Number of active filter axes; used by the toolbar badge.
    var activeFilterCount: Int {
        var n = 0
        if !selectedTags.isEmpty { n += 1 }
        if maxCookTimeMinutes != nil { n += 1 }
        if maxPrepTimeMinutes != nil { n += 1 }
        if difficulty != nil { n += 1 }
        if course != nil { n += 1 }
        return n
    }

    /// True when no filter axis is active.
    var isEmpty: Bool { activeFilterCount == 0 }

    /// Returns true when `recipe` passes every active filter axis.
    /// Tags use OR semantics within the set; all axes compose with AND.
    func matches(_ recipe: Recipe) -> Bool {
        let md = recipe.metadata

        if !selectedTags.isEmpty {
            guard !selectedTags.isDisjoint(with: Set(md.normalizedTags)) else { return false }
        }

        if let maxCook = maxCookTimeMinutes {
            let cookTime = md.minutes(forKey: "cook time") ?? md.minutes(forKey: "cook_time")
            guard let cookTime, cookTime <= maxCook else { return false }
        }

        if let maxPrep = maxPrepTimeMinutes {
            let prepTime = md.minutes(forKey: "prep time") ?? md.minutes(forKey: "prep_time")
            guard let prepTime, prepTime <= maxPrep else { return false }
        }

        if let required = difficulty {
            guard let value = md["difficulty"],
                  value.localizedCaseInsensitiveCompare(required) == .orderedSame else { return false }
        }

        if let required = course {
            let value = md["meal type"] ?? md["meal_type"]
            guard let value,
                  value.localizedCaseInsensitiveCompare(required) == .orderedSame else { return false }
        }

        return true
    }
}

extension RecipesActiveFilters {
    static let inactive = RecipesActiveFilters()
}
