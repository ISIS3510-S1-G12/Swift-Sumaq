//
//  LRUCache.swift
//  SUMAQ
//
//  Created by RODRIGO PAZ LONDO�O on 30/10/25.
//

import Foundation
import Foundation

public actor LRUCache<Key: Hashable, Value> {

    private final class Node {
        let key: Key
        var value: Value
        var cost: Int
        var prev: Node?
        var next: Node?
        init(key: Key, value: Value, cost: Int) {
            self.key = key
            self.value = value
            self.cost = cost
        }
    }

    private var dict: [Key: Node] = [:]
    private var head: Node?
    private var tail: Node?

    private let countLimit: Int
    private let costLimit: Int
    private var totalCost = 0

    public init(countLimit: Int = 300, costLimit: Int = 64 * 1024 * 1024) {
        precondition(countLimit > 0 && costLimit > 0)
        self.countLimit = countLimit
        self.costLimit  = costLimit
    }

    public func value(for key: Key) -> Value? {
        guard let node = dict[key] else { return nil }
        moveToFront(node)
        return node.value
    }

    public func set(_ value: Value, for key: Key, cost: Int = 1) {
        if let node = dict[key] {
            totalCost -= node.cost
            node.value = value
            node.cost  = max(1, cost)
            totalCost += node.cost
            moveToFront(node)
        } else {
            let node = Node(key: key, value: value, cost: max(1, cost))
            dict[key] = node
            insertAtFront(node)
            totalCost += node.cost
        }
        evictIfNeeded()
    }

    public func remove(_ key: Key) {
        guard let node = dict.removeValue(forKey: key) else { return }
        removeNode(node)
        totalCost -= node.cost
    }

    public func removeAll() {
        dict.removeAll(); head = nil; tail = nil; totalCost = 0
    }

    // MARK: - Lista doble
    private func insertAtFront(_ node: Node) {
        node.prev = nil; node.next = head
        head?.prev = node; head = node
        if tail == nil { tail = node }
    }
    private func moveToFront(_ node: Node) {
        guard head !== node else { return }
        removeNode(node); insertAtFront(node)
    }
    private func removeNode(_ node: Node) {
        let p = node.prev, n = node.next
        if let p { p.next = n } else { head = n }
        if let n { n.prev = p } else { tail = p }
        node.prev = nil; node.next = nil
    }
    private func evictIfNeeded() {
        while (dict.count > countLimit || totalCost > costLimit), let lru = tail {
            dict.removeValue(forKey: lru.key)
            totalCost -= lru.cost
            removeNode(lru)
        }
    }
}
