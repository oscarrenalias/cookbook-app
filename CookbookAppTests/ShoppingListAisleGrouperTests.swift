import Testing
@testable import CookbookApp
import CookbookCore
import Foundation

@Suite("ShoppingListAisleGrouper")
struct ShoppingListAisleGrouperTests {

    @Test func nilBucketContainsItemsBeforeFirstHeading() {
        let list = ShoppingList("- [ ] loose item\n## produce\n- [ ] carrot\n")
        let groups = ShoppingListAisleGrouper.group(list)
        let nilGroup = groups.first { $0.name == nil }
        #expect(nilGroup != nil)
        #expect(nilGroup!.items.count == 1)
        #expect(nilGroup!.items[0].text == "loose item")
    }

    @Test func sectionSwitchGroupsItemsIntoCorrectBuckets() {
        let list = ShoppingList("## produce\n- [ ] carrot\n## dairy\n- [ ] milk\n")
        let groups = ShoppingListAisleGrouper.group(list)
        let namedGroups = groups.filter { $0.name != nil }
        #expect(namedGroups.count == 2)
        let produceGroup = namedGroups.first { $0.name == "produce" }
        let dairyGroup = namedGroups.first { $0.name == "dairy" }
        #expect(produceGroup?.items.count == 1)
        #expect(produceGroup?.items.first?.text == "carrot")
        #expect(dairyGroup?.items.count == 1)
        #expect(dairyGroup?.items.first?.text == "milk")
    }

    @Test func consecutiveHeadingsProduceEmptyIntermediateSection() {
        let list = ShoppingList("## produce\n## dairy\n- [ ] milk\n")
        let groups = ShoppingListAisleGrouper.group(list)
        let produceGroup = groups.first { $0.name == "produce" }
        let dairyGroup = groups.first { $0.name == "dairy" }
        #expect(produceGroup?.items.isEmpty == true)
        #expect(dairyGroup?.items.count == 1)
        #expect(dairyGroup?.items.first?.text == "milk")
    }
}
