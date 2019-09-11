import Darwin

precedencegroup StreamAddition {
  higherThan: AdditionPrecedence
  associativity: right
}

precedencegroup StreamLeft {
  higherThan: StreamAddition
  associativity: left
}

precedencegroup StreamRight {
  higherThan: StreamLeft
  associativity: right
}

precedencegroup StreamOptional {
  higherThan: StreamRight
  associativity: right
}

// Performs zip on two operands with map droping rhs
infix operator ~>>: StreamRight
// Performs zip on two operands with map droping lhs
infix operator <<~: StreamLeft
// Equivalent to zip(rhs, lhs)
infix operator ~: StreamAddition

// "Zero or more"
postfix operator *
// "One or more"
postfix operator +
// "Zero or one"
postfix operator ~?

public struct Parser<D, T> {
  public struct GenericError: Error {
    public var text: D

    var localizedDescription: String {
      return "Couldn't parse \(T.self) from <\(text)>"
    }

    @inlinable
    public init(_ text: D) {
      self.text = text
    }
  }

  public typealias Error = Swift.Error

  public var parse: (inout D) -> Result<T, Error>

  @inlinable
  public func run(_ data: inout D) -> T? {
    return parse(&data).value
  }

  @inlinable
  public func run(_ data: D) -> Result<T, Error> {
    var copy = data
    return parse(&copy)
  }

  @inlinable
  public init(_ parse: @escaping (inout D) -> Result<T, Error>) {
    self.parse = parse
  }

  @inlinable
  public static func opt(parse: @escaping (inout D) -> T?) -> Parser<D, T> {
    return .init {
      .init(optional: parse(&$0), or: GenericError($0))
    }
  }

  @inlinable
  public static func always(_ t: T) -> Parser<D, T> {
    return .init(Base.always(.success(t)))
  }

  @inlinable
  public static func never() -> Parser<D, T> {
    return .init(Base.always(.failure(ParseError.never)))
  }

  @inlinable
  public func map<T1>(_ t: @escaping (T) -> T1) -> Parser<D, T1> {
    return .init { self.parse(&$0).map(t) }
  }

  @inlinable
  public func flatMap<T1>(
    _ t: @escaping (T) -> (Parser<D, T1>)
  ) -> Parser<D, T1> {
    return Parser<D, T1> { data in
      let original = data
      let res = self.parse(&data).flatMap { t($0).parse(&data) }
      switch res {
      case .failure:
        data = original
      case .success:
        break
      }
      return res
    }
  }

  @inlinable
  public func flatMapResult<T1>(
    _ t: @escaping (T) -> (Result<T1, Error>)
  ) -> Parser<D, T1> {
    return Parser<D, T1> { data in
      self.parse(&data).flatMap(t)
    }
  }
}

extension Parser where D == T, D: RangeReplaceableCollection {
  @inlinable
  public static func identity() -> Parser<D, D> {
    return .init { data in
      defer { data.removeAll(keepingCapacity: false) }
      return .success(data)
    }
  }
}

public func atIndex<D: RangeReplaceableCollection>(idx: D.Index) -> Parser<D, D.Element> {
  return .opt {
    $0.remove(at: idx)
  }
}

public func key<K, V>(key: K) -> Parser<[K: V], V> {
  return .opt {
    $0.removeValue(forKey: key)
  }
}

@inlinable
public func zip<A1, A2, D, R>(
  _ p1: Parser<D, A1>,
  _ p2: Parser<D, A2>,
  with f: @escaping (A1, A2) -> R
) -> Parser<D, R> {
  return p1.flatMap { a in p2.map { b in f(a, b) } }
}

@inlinable
public func zip<A1, A2, A3, D, R>(
  _ p1: Parser<D, A1>,
  _ p2: Parser<D, A2>,
  _ p3: Parser<D, A3>,
  with f: @escaping (A1, A2, A3) -> R
) -> Parser<D, R> {
  return zip(p1, zip(p2, p3, with: identity)) { f($0, $1.0, $1.1) }
}

@inlinable
public func zip<A1, A2, A3, A4, D, R>(
  _ p1: Parser<D, A1>,
  _ p2: Parser<D, A2>,
  _ p3: Parser<D, A3>,
  _ p4: Parser<D, A4>,
  with f: @escaping (A1, A2, A3, A4) -> R
) -> Parser<D, R> {
  return zip(p1, zip(p2, p3, p4, with: identity)) { f($0, $1.0, $1.1, $1.2) }
}

@inlinable
public func zip<A1, A2, A3, A4, A5, D, R>(
  _ p1: Parser<D, A1>,
  _ p2: Parser<D, A2>,
  _ p3: Parser<D, A3>,
  _ p4: Parser<D, A4>,
  _ p5: Parser<D, A5>,
  with f: @escaping (A1, A2, A3, A4, A5) -> R
) -> Parser<D, R> {
  return zip(p1, zip(p2, p3, p4, p5, with: identity))
  { f($0, $1.0, $1.1, $1.2, $1.3) }
}

@inlinable
public func zip<A1, A2, A3, A4, A5, A6, R, D>(
  _ p1: Parser<D, A1>,
  _ p2: Parser<D, A2>,
  _ p3: Parser<D, A3>,
  _ p4: Parser<D, A4>,
  _ p5: Parser<D, A5>,
  _ p6: Parser<D, A6>,
  with f: @escaping (A1, A2, A3, A4, A5, A6) -> R
) -> Parser<D, R> {
  return zip(p1, zip(p2, p3, p4, p5, p6, with: identity))
  { f($0, $1.0, $1.1, $1.2, $1.3, $1.4) }
}

@inlinable
public func zip<A1, A2, A3, A4, A5, A6, A7, D, R>(
  _ p1: Parser<D, A1>,
  _ p2: Parser<D, A2>,
  _ p3: Parser<D, A3>,
  _ p4: Parser<D, A4>,
  _ p5: Parser<D, A5>,
  _ p6: Parser<D, A6>,
  _ p7: Parser<D, A7>,
  with f: @escaping (A1, A2, A3, A4, A5, A6, A7) -> R
) -> Parser<D, R> {
  return zip(p1, zip(p2, p3, p4, p5, p6, p7, with: identity))
  { f($0, $1.0, $1.1, $1.2, $1.3, $1.4, $1.5) }
}

@inlinable
public func zip<A1, A2, A3, A4, A5, A6, A7, A8, D, R>(
  _ p1: Parser<D, A1>,
  _ p2: Parser<D, A2>,
  _ p3: Parser<D, A3>,
  _ p4: Parser<D, A4>,
  _ p5: Parser<D, A5>,
  _ p6: Parser<D, A6>,
  _ p7: Parser<D, A7>,
  _ p8: Parser<D, A8>,
  with f: @escaping (A1, A2, A3, A4, A5, A6, A7, A8) -> R
) -> Parser<D, R> {
  return zip(p1, zip(p2, p3, p4, p5, p6, p7, p8, with: identity))
  { f($0, $1.0, $1.1, $1.2, $1.3, $1.4, $1.5, $1.6) }
}

@inlinable
public func zip<A1, A2, A3, A4, A5, A6, A7, A8, A9, D, R>(
  _ p1: Parser<D, A1>,
  _ p2: Parser<D, A2>,
  _ p3: Parser<D, A3>,
  _ p4: Parser<D, A4>,
  _ p5: Parser<D, A5>,
  _ p6: Parser<D, A6>,
  _ p7: Parser<D, A7>,
  _ p8: Parser<D, A8>,
  _ p9: Parser<D, A9>,
  with f: @escaping (A1, A2, A3, A4, A5, A6, A7, A8, A9) -> R
) -> Parser<D, R> {
  return zip(p1, zip(p2, p3, p4, p5, p6, p7, p8, p9, with: identity))
  { f($0, $1.0, $1.1, $1.2, $1.3, $1.4, $1.5, $1.6, $1.7) }
}

@inlinable
public func zip<A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, D, R>(
  _ p1: Parser<D, A1>,
  _ p2: Parser<D, A2>,
  _ p3: Parser<D, A3>,
  _ p4: Parser<D, A4>,
  _ p5: Parser<D, A5>,
  _ p6: Parser<D, A6>,
  _ p7: Parser<D, A7>,
  _ p8: Parser<D, A8>,
  _ p9: Parser<D, A9>,
  _ p10: Parser<D, A10>,
  with f: @escaping (A1, A2, A3, A4, A5, A6, A7, A8, A9, A10) -> R
) -> Parser<D, R> {
  return zip(p1, zip(p2, p3, p4, p5, p6, p7, p8, p9, p10, with: identity))
  { f($0, $1.0, $1.1, $1.2, $1.3, $1.4, $1.5, $1.6, $1.7, $1.8) }
}

@inlinable
public func zip<A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, D, R>(
  _ p1: Parser<D, A1>,
  _ p2: Parser<D, A2>,
  _ p3: Parser<D, A3>,
  _ p4: Parser<D, A4>,
  _ p5: Parser<D, A5>,
  _ p6: Parser<D, A6>,
  _ p7: Parser<D, A7>,
  _ p8: Parser<D, A8>,
  _ p9: Parser<D, A9>,
  _ p10: Parser<D, A10>,
  _ p11: Parser<D, A11>,
  with f: @escaping (A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11) -> R
) -> Parser<D, R> {
  return zip(p1, zip(p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, with: identity))
  { f($0, $1.0, $1.1, $1.2, $1.3, $1.4, $1.5, $1.6, $1.7, $1.8, $1.9) }
}

@inlinable
public func zip<A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12, D, R>(
  _ p1: Parser<D, A1>,
  _ p2: Parser<D, A2>,
  _ p3: Parser<D, A3>,
  _ p4: Parser<D, A4>,
  _ p5: Parser<D, A5>,
  _ p6: Parser<D, A6>,
  _ p7: Parser<D, A7>,
  _ p8: Parser<D, A8>,
  _ p9: Parser<D, A9>,
  _ p10: Parser<D, A10>,
  _ p11: Parser<D, A11>,
  _ p12: Parser<D, A12>,
  with f: @escaping (A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12) -> R
) -> Parser<D, R> {
  return zip(p1, zip(p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, with: identity))
  { f($0, $1.0, $1.1, $1.2, $1.3, $1.4, $1.5, $1.6, $1.7, $1.8, $1.9, $1.10) }
}

@inlinable
public func zip<A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12, A13, D, R>(
  _ p1: Parser<D, A1>,
  _ p2: Parser<D, A2>,
  _ p3: Parser<D, A3>,
  _ p4: Parser<D, A4>,
  _ p5: Parser<D, A5>,
  _ p6: Parser<D, A6>,
  _ p7: Parser<D, A7>,
  _ p8: Parser<D, A8>,
  _ p9: Parser<D, A9>,
  _ p10: Parser<D, A10>,
  _ p11: Parser<D, A11>,
  _ p12: Parser<D, A12>,
  _ p13: Parser<D, A13>,
  with f: @escaping (A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12, A13) -> R
) -> Parser<D, R> {
  return zip(p1, zip(p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, p13, with: identity))
  { f($0, $1.0, $1.1, $1.2, $1.3, $1.4, $1.5, $1.6, $1.7, $1.8, $1.9, $1.10, $1.11) }
}

@inlinable
public func maybe<D, T>(_ p: Parser<D, T>) -> Parser<D, T?> {
  return .init {
    p.parse(&$0).map(Optional.some).flatMapError(always(.success(nil)))
  }
}

@inlinable
public func maybe<D>(_ p: Parser<D, Void>) -> Parser<D, Void> {
  return .init {
    p.parse(&$0).flatMapError(always(.success(())))
  }
}

@inlinable
public func zeroOrMore<D, A, S>(
  _ p: Parser<D, A>,
  separator: Parser<D, S>
) -> Parser<D, [A]> {
  return .init {
    var matches: [A] = []
    var lastBeforeSeparator = $0
    var firstOrHasSeparatorBefore = true
    while case let .success(match) = p.parse(&$0), firstOrHasSeparatorBefore {
      matches.append(match)
      lastBeforeSeparator = $0
      firstOrHasSeparatorBefore = separator.parse(&$0).isSucceed
    }
    $0 = lastBeforeSeparator
    return .success(matches)
  }
}

@inlinable
public func zeroOrMore<D, A>(
  _ p: Parser<D, A>
) -> Parser<D, [A]> {
  return zeroOrMore(p, separator: .always(()))
}

public enum ParseError: Error {
  case atLeastOneExpected
  case consume(expected: String, got: String)
  case never
  case couldntConvertStringTo(type: String)
  case parsingNotComplete(last: String)
}

@inlinable
public func oneOrMore<D, A, S>(
  _ p: Parser<D, A>,
  separator: Parser<D, S>
) -> Parser<D, [A]> {
  return zeroOrMore(p, separator: separator).flatMapResult {
    $0.count == 0 ? .failure(ParseError.atLeastOneExpected) : .success($0)
  }
}

@inlinable
public func oneOrMore<D, A>(
  _ p: Parser<D, A>
) -> Parser<D, [A]> {
  return oneOrMore(p, separator: .always(()))
}

@inlinable
public func consume<C: Collection>(
  element: C.Element
) -> Parser<C, Void> where C.SubSequence == C, C.Element: Equatable {
  return .opt {
    guard let first = $0.first, element == first else {
      return nil
    }
    $0.removeFirst()
    return ()
  }
}

@inlinable
public func consume<C: Collection>(
  while predicate: @escaping (C.Element) -> Bool
) -> Parser<C, C.SubSequence> where C.SubSequence == C {
  return .opt {
    let result = $0.prefix(while: predicate)
    $0.removeFirst(result.count)
    return result
  }
}

@inlinable
public func skipZeroOrMore<C: Collection>(
  chars: Set<C.Element>
) -> Parser<C, Void> where C.SubSequence == C {
  return .init {
    let prefix = $0.prefix(while: chars.contains)
    $0.removeFirst(prefix.count)
    return .success(())
  }
}

@inlinable
public func skipZeroOrMore<C: Collection>(
  char: C.Element
) -> Parser<C, Void> where C.SubSequence == C, C.Element: Hashable {
  return skipZeroOrMore(chars: [char])
}

@inlinable
public func skipOneOrMore<C: Collection>(
  chars: Set<C.Element>
) -> Parser<C, Void> where C.SubSequence == C {
  return .opt {
    let prefix = $0.prefix(while: chars.contains)
    guard prefix.count == 0 else {
      return nil
    }
    $0.removeFirst(prefix.count)
    return ()
  }
}

@inlinable
public func skipOneOrMore<C: Collection>(
  char: C.Element
) -> Parser<C, Void> where C.SubSequence == C, C.Element: Hashable {
  return skipOneOrMore(chars: [char])
}

@inlinable
public func oneOf<D, A>(_ ps: [Parser<D, A>]) -> Parser<D, A> {
  return .opt { str in
    for p in ps {
      if case let .success(match) = p.parse(&str) {
        return match
      }
    }
    return nil
  }
}

@inlinable
public func read<D: Collection>(
  exactly n: Int
) -> Parser<D, D.SubSequence> where D.SubSequence == D {
  return .opt { data in
    let prefix = data.prefix(n)
    guard prefix.count == n else { return nil }
    data.removeFirst(n)
    return prefix
  }
}

@inlinable
public func readOne<D: Collection>(
) -> Parser<D, D.Element> where D.SubSequence == D {
  return .opt { $0.popFirst() }
}

@inlinable
public func oneOf<D, T: CaseIterable & RawRepresentable>(
  parserFactory: @escaping (T.RawValue) -> Parser<D, Void>,
  _: T.Type = T.self
) -> Parser<D, T> {
  return oneOf(T.allCases.map { parserFactory($0.rawValue).map(always($0)) })
}

@inlinable
public func endof<D: Collection>(_: D.Type = D.self) -> Parser<D, Void> {
  return .init {
    $0.count == 0 ?
      .success(()) :
      .failure(ParseError.parsingNotComplete(last: "\($0)"))
  }
}

@inlinable
public func ~>> <D, T, T1>(
  lhs: Parser<D, T1>, rhs: Parser<D, T>
) -> Parser<D, T> {
  return zip(lhs, rhs) { $1 }
}

@inlinable
public func <<~< D, T, T1 > (
  lhs: Parser<D, T>, rhs: Parser<D, T1>
) -> Parser<D, T> {
  return zip(lhs, rhs) { lhs, _ in lhs }
}

@inlinable
public func | <D, T>(lhs: Parser<D, T>, rhs: Parser<D, T>) -> Parser<D, T> {
  return oneOf([lhs, rhs])
}

@inlinable
public func ~ <D, T1, T2>(
  lhs: Parser<D, T1>, rhs: Parser<D, T2>
) -> Parser<D, (T1, T2)> {
  return zip(lhs, rhs, with: identity)
}

@inlinable
public postfix func ~? <D, T>(p: Parser<D, T>) -> Parser<D, T?> {
  return maybe(p)
}

@inlinable
public postfix func * <D, T>(p: Parser<D, T>) -> Parser<D, [T]> {
  return zeroOrMore(p)
}

@inlinable
public postfix func + <D, T>(p: Parser<D, T>) -> Parser<D, [T]> {
  return oneOrMore(p)
}

// String parsers

extension Parser:
  ExpressibleByStringLiteral,
  ExpressibleByExtendedGraphemeClusterLiteral,
  ExpressibleByUnicodeScalarLiteral
  where D: StringProtocol, T == Void, D.SubSequence == D {
  @inlinable
  public init(stringLiteral value: StaticString) {
    let s = value.description
    self.init { (data) -> Result<Void, Error> in
      guard data.hasPrefix(s) else {
        return .failure(ParseError.consume(
          expected: value.description,
          got: data.prefix(s.count).description
        ))
      }
      data.removeFirst(s.count)
      return .success(())
    }
  }

  @inlinable
  public init(extendedGraphemeClusterLiteral value: StaticString) {
    self.init(stringLiteral: value)
  }

  @inlinable
  public init(unicodeScalarLiteral value: StaticString) {
    self.init(stringLiteral: value)
  }
}

extension Parser where D == Substring {
  @inlinable
  public func whole(_ s: String) -> Result<T, Error> {
    var copy = D(s)
    return (self <<~ endof()).parse(&copy)
  }
}

@inlinable
public func oneOf<D: StringProtocol, T: CaseIterable & RawRepresentable>(
  _: T.Type = T.self
) -> Parser<D, T>
  where T.RawValue: StringProtocol, D.SubSequence == D {
  return oneOf(T.allCases.map { consume(String($0.rawValue)).map(always($0)) })
}

@inlinable
public func consume<S: StringProtocol>(
  _ s: String
) -> Parser<S, Void> where S.SubSequence == S {
  return .init { (data) -> Result<Void, Error> in
    guard data.hasPrefix(s) else {
      return .failure(
        ParseError.consume(expected: s, got: data.prefix(s.count).description)
      )
    }
    data.removeFirst(s.count)
    return .success(())
  }
}

@inlinable
public func int<S: StringProtocol>(
  from _: S.Type = S.self,
  radix: Int32 = 10
) -> Parser<S, Int> where S.SubSequence == S {
  return .opt {
    // Fail on any leading whitespace, as `strtol` skips it.
    guard let first = $0.first, !first.isWhitespace else { return nil }
    let (res, len) = $0.withCString { (cstr) -> (Int, Int) in
      var endPointer: UnsafeMutablePointer<Int8>?
      let res = strtol(cstr, &endPointer, radix)
      guard let intEndPointee = endPointer else { return (0, 0) }
      let len = cstr.distance(to: intEndPointee)
      return (res, len)
    }
    guard len > 0 else {
      return nil
    }
    $0.removeFirst(len)
    return res
  }
}

@inlinable
public func double<S: StringProtocol>(
) -> Parser<S, Double> where S.SubSequence == S {
  return .opt {
    // Fail on any leading whitespace, as `strtod` skips it.
    guard let first = $0.first, !first.isWhitespace else { return nil }
    let (res, len) = $0.withCString { (cstr) -> (Double, Int) in
      var endPointer: UnsafeMutablePointer<Int8>?
      let res = strtod(cstr, &endPointer)
      guard let doubleEndPointee = endPointer else { return (0, 0) }
      let len = cstr.distance(to: doubleEndPointee)
      return (res, len)
    }
    guard len > 0 else {
      return nil
    }
    $0.removeFirst(len)
    return res
  }
}