import Testing
@testable import CookbookCore

@Suite("MealPlan Mutations")
struct MealPlanMutationTests {

    // MARK: - addItem

    @Test func addItemAppendsToValidBlockAndSection() {
        var plan = MealPlan(blocks: [
            MealPlanBlock(heading: "Day 1", sections: [MealPlanSection()])
        ])
        let item = MealPlanItem.recipe(MealPlanRecipe(path: "./Pasta/Bolognese"))
        plan.addItem(item, toBlock: 0, section: 0)

        #expect(plan.blocks[0].sections[0].items.count == 1)
        guard case .recipe(let r) = plan.blocks[0].sections[0].items[0] else {
            Issue.record("Expected recipe item")
            return
        }
        #expect(r.path == "./Pasta/Bolognese")
    }

    @Test func addItemAppendsToTailOfExistingItems() {
        var plan = MealPlan(blocks: [
            MealPlanBlock(heading: "Day 1", sections: [
                MealPlanSection(items: [.recipe(MealPlanRecipe(path: "./Soup/Minestrone"))])
            ])
        ])
        plan.addItem(.recipe(MealPlanRecipe(path: "./Pasta/Bolognese")), toBlock: 0, section: 0)

        #expect(plan.blocks[0].sections[0].items.count == 2)
        guard case .recipe(let r) = plan.blocks[0].sections[0].items[1] else {
            Issue.record("Expected appended recipe at position 1")
            return
        }
        #expect(r.path == "./Pasta/Bolognese")
    }

    @Test func addItemIsNoOpForOutOfBoundsBlockIndex() {
        var plan = MealPlan(blocks: [
            MealPlanBlock(heading: "Day 1", sections: [MealPlanSection()])
        ])
        let before = plan
        plan.addItem(.recipe(MealPlanRecipe(path: "./X/Y")), toBlock: 99, section: 0)
        #expect(plan == before)
    }

    @Test func addItemIsNoOpForOutOfBoundsSectionIndex() {
        var plan = MealPlan(blocks: [
            MealPlanBlock(heading: "Day 1", sections: [MealPlanSection()])
        ])
        let before = plan
        plan.addItem(.recipe(MealPlanRecipe(path: "./X/Y")), toBlock: 0, section: 99)
        #expect(plan == before)
    }

    @Test func addItemTargetsCorrectSectionWhenMultipleSectionsExist() {
        var plan = MealPlan(blocks: [
            MealPlanBlock(heading: "Day 1", sections: [
                MealPlanSection(name: "Breakfast", items: []),
                MealPlanSection(name: "Dinner", items: [])
            ])
        ])
        plan.addItem(.recipe(MealPlanRecipe(path: "./Eggs/Scrambled")), toBlock: 0, section: 1)

        #expect(plan.blocks[0].sections[0].items.isEmpty)
        #expect(plan.blocks[0].sections[1].items.count == 1)
    }

    // MARK: - addBlock

    @Test func addBlockReturnsNewBlockIndexOnEmptyPlan() {
        var plan = MealPlan()
        let idx = plan.addBlock(named: "Day 1")
        #expect(idx == 0)
    }

    @Test func addBlockReturnsIncrementingIndex() {
        var plan = MealPlan()
        let first = plan.addBlock(named: "Day 1")
        let second = plan.addBlock(named: "Day 2")
        #expect(first == 0)
        #expect(second == 1)
    }

    @Test func addBlockSeedsExactlyOneEmptySection() {
        var plan = MealPlan()
        plan.addBlock(named: "Day 1")
        #expect(plan.blocks[0].sections.count == 1)
        #expect(plan.blocks[0].sections[0].items.isEmpty)
    }

    @Test func addBlockIncreasesBlockCountByOne() {
        var plan = MealPlan(blocks: [
            MealPlanBlock(heading: "Existing", sections: [MealPlanSection()])
        ])
        plan.addBlock(named: "New Block")
        #expect(plan.blocks.count == 2)
    }

    @Test func addBlockAllowsDuplicateHeadings() {
        var plan = MealPlan()
        plan.addBlock(named: "Day 1")
        plan.addBlock(named: "Day 1")
        #expect(plan.blocks.count == 2)
        #expect(plan.blocks[0].heading == "Day 1")
        #expect(plan.blocks[1].heading == "Day 1")
    }

    @Test func addBlockSetsProvidedHeading() {
        var plan = MealPlan()
        plan.addBlock(named: "Batch Prep")
        #expect(plan.blocks[0].heading == "Batch Prep")
    }

    // MARK: - Round-trip serialisation

    @Test func addedItemSurvivesRoundTrip() {
        var plan = MealPlan(blocks: [
            MealPlanBlock(heading: "Day 1", sections: [MealPlanSection()])
        ])
        plan.addItem(.recipe(MealPlanRecipe(path: "./Pasta/Bolognese")), toBlock: 0, section: 0)

        let serialised = MealPlanParser.serialise(plan)
        let reparsed = MealPlanParser.parse(serialised)

        #expect(reparsed == plan)
        guard case .recipe(let r) = reparsed.blocks[0].sections[0].items[0] else {
            Issue.record("Expected recipe after round trip")
            return
        }
        #expect(r.path == "./Pasta/Bolognese")
    }

    @Test func addedBlockSurvivesRoundTrip() {
        var plan = MealPlan(blocks: [
            MealPlanBlock(heading: "Day 1", sections: [MealPlanSection()])
        ])
        let newIdx = plan.addBlock(named: "Day 2")
        plan.addItem(.recipe(MealPlanRecipe(path: "./Soup/Minestrone")), toBlock: newIdx, section: 0)

        let serialised = MealPlanParser.serialise(plan)
        let reparsed = MealPlanParser.parse(serialised)

        #expect(reparsed.blocks.count == 2)
        #expect(reparsed.blocks[1].heading == "Day 2")
        guard case .recipe(let r) = reparsed.blocks[1].sections[0].items[0] else {
            Issue.record("Expected recipe in new block after round trip")
            return
        }
        #expect(r.path == "./Soup/Minestrone")
    }

    // MARK: - moveBlock

    @Test func moveBlockForwardShiftsIntermediateBlocksLeft() {
        var plan = MealPlan(blocks: [
            MealPlanBlock(heading: "A", sections: [MealPlanSection()]),
            MealPlanBlock(heading: "B", sections: [MealPlanSection()]),
            MealPlanBlock(heading: "C", sections: [MealPlanSection()]),
        ])
        plan.moveBlock(from: 0, to: 2)
        #expect(plan.blocks[0].heading == "B")
        #expect(plan.blocks[1].heading == "C")
        #expect(plan.blocks[2].heading == "A")
    }

    @Test func moveBlockBackwardShiftsIntermediateBlocksRight() {
        var plan = MealPlan(blocks: [
            MealPlanBlock(heading: "A", sections: [MealPlanSection()]),
            MealPlanBlock(heading: "B", sections: [MealPlanSection()]),
            MealPlanBlock(heading: "C", sections: [MealPlanSection()]),
        ])
        plan.moveBlock(from: 2, to: 0)
        #expect(plan.blocks[0].heading == "C")
        #expect(plan.blocks[1].heading == "A")
        #expect(plan.blocks[2].heading == "B")
    }

    @Test func moveBlockSameIndexIsNoOp() {
        var plan = MealPlan(blocks: [
            MealPlanBlock(heading: "A", sections: [MealPlanSection()]),
            MealPlanBlock(heading: "B", sections: [MealPlanSection()]),
        ])
        let before = plan
        plan.moveBlock(from: 0, to: 0)
        #expect(plan == before)
    }

    @Test func moveBlockOutOfBoundsSourceIsNoOp() {
        var plan = MealPlan(blocks: [
            MealPlanBlock(heading: "A", sections: [MealPlanSection()]),
        ])
        let before = plan
        plan.moveBlock(from: 99, to: 0)
        #expect(plan == before)
    }

    @Test func moveBlockOutOfBoundsDestinationIsNoOp() {
        var plan = MealPlan(blocks: [
            MealPlanBlock(heading: "A", sections: [MealPlanSection()]),
        ])
        let before = plan
        plan.moveBlock(from: 0, to: 99)
        #expect(plan == before)
    }

    @Test func moveBlockPreservesInnerSectionsAndItems() {
        let item = MealPlanItem.recipe(MealPlanRecipe(path: "./Pasta/Bolognese"))
        var plan = MealPlan(blocks: [
            MealPlanBlock(heading: "Day 1", sections: [
                MealPlanSection(name: "Dinner", items: [item])
            ]),
            MealPlanBlock(heading: "Day 2", sections: [MealPlanSection()]),
        ])
        plan.moveBlock(from: 0, to: 1)
        #expect(plan.blocks[0].heading == "Day 2")
        #expect(plan.blocks[1].heading == "Day 1")
        #expect(plan.blocks[1].sections.count == 1)
        #expect(plan.blocks[1].sections[0].name == "Dinner")
        #expect(plan.blocks[1].sections[0].items.count == 1)
        guard case .recipe(let r) = plan.blocks[1].sections[0].items[0] else {
            Issue.record("Expected recipe item after move")
            return
        }
        #expect(r.path == "./Pasta/Bolognese")
    }

    // MARK: - renameBlock

    @Test func renameBlockChangesHeading() {
        var plan = MealPlan(blocks: [
            MealPlanBlock(heading: "Old Name", sections: [MealPlanSection()])
        ])
        plan.renameBlock(at: 0, to: "New Name")
        #expect(plan.blocks[0].heading == "New Name")
    }

    @Test func renameBlockTrimsLeadingAndTrailingWhitespace() {
        var plan = MealPlan(blocks: [
            MealPlanBlock(heading: "Day 1", sections: [MealPlanSection()])
        ])
        plan.renameBlock(at: 0, to: "  Day 1 Trimmed  ")
        #expect(plan.blocks[0].heading == "Day 1 Trimmed")
    }

    @Test func renameBlockOutOfBoundsIsNoOp() {
        var plan = MealPlan(blocks: [
            MealPlanBlock(heading: "Day 1", sections: [MealPlanSection()])
        ])
        let before = plan
        plan.renameBlock(at: 99, to: "New Name")
        #expect(plan == before)
    }

    @Test func renameBlockPreservesInnerSectionsAndItems() {
        let item = MealPlanItem.recipe(MealPlanRecipe(path: "./Pasta/Bolognese"))
        var plan = MealPlan(blocks: [
            MealPlanBlock(heading: "Day 1", sections: [
                MealPlanSection(name: "Dinner", items: [item]),
                MealPlanSection(name: "Lunch", items: [])
            ])
        ])
        plan.renameBlock(at: 0, to: "Monday")
        #expect(plan.blocks[0].heading == "Monday")
        #expect(plan.blocks[0].sections.count == 2)
        #expect(plan.blocks[0].sections[0].name == "Dinner")
        #expect(plan.blocks[0].sections[0].items.count == 1)
        #expect(plan.blocks[0].sections[1].name == "Lunch")
    }
}
