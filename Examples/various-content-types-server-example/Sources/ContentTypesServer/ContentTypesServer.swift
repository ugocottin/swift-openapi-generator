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

    func getExampleJSON(_ input: Operations.GetExampleJSON.Input) async throws -> Operations.GetExampleJSON.Output {
        let name = input.query.name ?? "Stranger"
        print("Greeting a person with the name: \(name)")
        return .ok(.init(body: .json(.init(message: "Hello, \(name)!"))))
    }

    func postExampleJSON(_ input: Operations.PostExampleJSON.Input) async throws -> Operations.PostExampleJSON.Output {
        let requestBody: Components.Schemas.Greeting
        switch input.body {
        case .json(let json): requestBody = json
        }
        print("Received a greeting with the message: '\(requestBody.message)'")
        return .accepted(.init())
    }

    func getExamplePlainText(_ input: Operations.GetExamplePlainText.Input) async throws
        -> Operations.GetExamplePlainText.Output
    {
        .ok(
            .init(
                body: .plainText(
                    """
                    A snow log.
                    ---
                    [2023-12-24] It snowed.
                    [2023-12-25] It snowed even more.
                    """
                )
            )
        )
    }

    func postExamplePlainText(_ input: Operations.PostExamplePlainText.Input) async throws
        -> Operations.PostExamplePlainText.Output
    {
        let plainText: HTTPBody
        switch input.body {
        case .plainText(let body): plainText = body
        }
        let bufferedText = try await String(collecting: plainText, upTo: 1024)
        print("Received text: \(bufferedText)")
        return .accepted(.init())
    }

    func getExampleMultipleContentTypes(_ input: Operations.GetExampleMultipleContentTypes.Input) async throws
        -> Operations.GetExampleMultipleContentTypes.Output
    {
        // The Accept header field lets the client communicate which response content type it prefers, by giving
        // each content type a "quality" (in other words, a preference), from 0.0 to 1.0, from least to most preferred.
        // However, the server is still in charge of choosing the response content type and uses the Accept header
        // as a hint only.
        //
        // As a server, here we sort the received content types in the Accept header by quality, from most to least
        // preferred. If none are provided, default to JSON.
        let chosenContentType = input.headers.accept.sortedByQuality().first?.contentType ?? .json
        let responseBody: Operations.GetExampleMultipleContentTypes.Output.Ok.Body
        switch chosenContentType {
        case .json, .other: responseBody = .json(.init(message: "Hello, Stranger!"))
        case .plainText: responseBody = .plainText("Hello, Stranger!")
        }
        return .ok(.init(body: responseBody))
    }

    func postExampleMultipleContentTypes(_ input: Operations.PostExampleMultipleContentTypes.Input) async throws
        -> Operations.PostExampleMultipleContentTypes.Output
    {
        switch input.body {
        case .json(let json): print("Received a JSON greeting with the message: \(json.message)")
        case .plainText(let body):
            let text = try await String(collecting: body, upTo: 1024)
            print("Received a text greeting with the message: \(text)")
        }
        return .accepted(.init())
    }

    func postExampleURLEncoded(_ input: Operations.PostExampleURLEncoded.Input) async throws
        -> Operations.PostExampleURLEncoded.Output
    {
        let requestBody: Operations.PostExampleURLEncoded.Input.Body.UrlEncodedFormPayload
        switch input.body {
        case .urlEncodedForm(let form): requestBody = form
        }
        print("Received a greeting with the message: '\(requestBody.message)'")
        return .accepted(.init())
    }

    func getExampleRawBytes(_ input: Operations.GetExampleRawBytes.Input) async throws
        -> Operations.GetExampleRawBytes.Output
    { .ok(.init(body: .binary([0x73, 0x6e, 0x6f, 0x77, 0x0a]))) }

    func postExampleRawBytes(_ input: Operations.PostExampleRawBytes.Input) async throws
        -> Operations.PostExampleRawBytes.Output
    {
        let binary: HTTPBody
        switch input.body {
        case .binary(let body): binary = body
        }
        // Processes each chunk as it comes in, avoids buffering the whole body into memory.
        for try await chunk in binary { print("Received chunk: \(chunk)") }
        return .accepted(.init())
    }

    func getExampleMultipart(_ input: Operations.GetExampleMultipart.Input) async throws
        -> Operations.GetExampleMultipart.Output
    {
        let multipartBody: MultipartBody<Operations.GetExampleMultipart.Output.Ok.Body.MultipartFormPayload> = [
            .greetingTemplate(.init(payload: .init(body: .init(message: "Hello, {name}!")))),
            .names(.init(payload: .init(headers: .init(xNameLocale: "en_US"), body: "Frank"))),
            .names(.init(payload: .init(body: "Not Frank"))),
        ]
        return .ok(.init(body: .multipartForm(multipartBody)))
    }

    func postExampleMultipart(_ input: Operations.PostExampleMultipart.Input) async throws
        -> Operations.PostExampleMultipart.Output
    {
        let multipartBody: MultipartBody<Operations.PostExampleMultipart.Input.Body.MultipartFormPayload>
        switch input.body {
        case .multipartForm(let form): multipartBody = form
        }
        for try await part in multipartBody {
            switch part {
            case .greetingTemplate(let template):
                let message = template.payload.body.message
                print("Received a template message: \(message)")
            case .names(let name):
                let stringName = try await String(collecting: name.payload.body, upTo: 1024)
                // Multipart parts can have headers.
                let locale = name.payload.headers.xNameLocale ?? "<nil>"
                print("Received a name: '\(stringName)', header value: '\(locale)'")
            case .undocumented(let part):
                // Any part with a raw HTTPBody body must have its body consumed before moving on to the next part.
                let bytes = try await [UInt8](collecting: part.body, upTo: 1024 * 1024)
                print("Received an undocumented part with \(part.headerFields.count) headers and \(bytes.count) bytes.")
            }
        }
        return .accepted(.init())
    }
}

@main struct ContentTypesServer {
    static func main() async throws {
        let app = try await Vapor.Application.make()
        let transport = VaporTransport(routesBuilder: app)
        let handler = Handler()
        try handler.registerHandlers(on: transport, serverURL: URL(string: "/api")!)
        try await app.execute()
    }
}
