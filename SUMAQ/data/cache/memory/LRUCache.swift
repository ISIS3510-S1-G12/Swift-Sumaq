//
//  LRUCache.swift
//  SUMAQ
//
//  Created by RODRIGO PAZ LONDOÑO on 30/10/25.
//

import Foundation

public final class LRUCache<Key: Hashable, Value> {

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

    private let lock = NSLock()
    private var dict: [Key: Node] = [:]
    private var head: Node? // MRU
    private var tail: Node? // LRU
    private var totalCost = 0

    private let countLimit: Int
    private let costLimit: Int

    public init(countLimit: Int = 300, costLimit: Int = 64 * 1024 * 1024) {
        precondition(countLimit > 0 && costLimit > 0)
        self.countLimit = countLimit
        self.costLimit  = costLimit
    }

    public func value(for key: Key) -> Value? {
        lock.lock(); defer { lock.unlock() }
        guard let n = dict[key] else { return nil }
        moveToFront(n)
        return n.value
    }

    public func set(_ value: Value, for key: Key, cost: Int = 1) {
        let c = max(1, cost)
        lock.lock()
        if let n = dict[key] {
            totalCost -= n.cost
            n.value = value
            n.cost  = c
            totalCost += c
            moveToFront(n)
        } else {
            let n = Node(key: key, value: value, cost: c)
            dict[key] = n
            insertAtFront(n)
            totalCost += c
        }
        evictIfNeeded()
        lock.unlock()
    }

    public func remove(_ key: Key) {
        lock.lock(); defer { lock.unlock() }
        guard let node = dict.removeValue(forKey: key) else { return }
        removeNode(node)
        totalCost -= node.cost
    }

    public func removeAll() {
        lock.lock(); defer { lock.unlock() }
        dict.removeAll(); head = nil; tail = nil; totalCost = 0
    }

    // MARK: - Lista doble
    private func insertAtFront(_ n: Node) {
        n.prev = nil; n.next = head
        head?.prev = n; head = n
        if tail == nil { tail = n }
    }

    private func moveToFront(_ n: Node) {
        guard head !== n else { return }
        removeNode(n); insertAtFront(n)
    }

    private func removeNode(_ n: Node) {
        let p = n.prev, nx = n.next
        if let p { p.next = nx } else { head = nx }
        if let nx { nx.prev = p } else { tail = p }
        n.prev = nil; n.next = nil
    }

    private func evictIfNeeded() {
        while (dict.count > countLimit || totalCost > costLimit), let lru = tail {
            dict.removeValue(forKey: lru.key)
            totalCost -= lru.cost
            removeNode(lru)
        }
    }
}
