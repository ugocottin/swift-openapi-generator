//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftOpenAPIGenerator open source project
//
// Copyright (c) 2023 Apple Inc. and the SwiftOpenAPIGenerator project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftOpenAPIGenerator project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
import OpenAPIRuntime
import OpenAPIVapor
import Vapor

struct Handler: APIProtocol {
    func getGreeting(_ input: Operations.GetGreeting.Input) async throws -> Operations.GetGreeting.Output {
        let name = input.query.name ?? "Stranger"
        return .ok(.init(body: .json(.init(message: "Hello, \(name)!"))))
    }
}

@main struct HelloWorldVaporServer {
    static func main() async throws {
        let app = try await Vapor.Application.make()
        let transport = VaporTransport(routesBuilder: app)
        let handler = Handler()
        try handler.registerHandlers(on: transport, serverURL: URL(string: "/api")!)
        try await app.execute()
    }
}
