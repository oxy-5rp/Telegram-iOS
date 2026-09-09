// MARK: Swiftgram
import Foundation
import UIKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramStringFormatting
import AccountContext
import ChatControllerInteraction
import ChatPresentationInterfaceState

/// Renders the revisions kept by `SGMessageEditHistoryAttribute` (plus the
/// current text) as a plain-text document and shows it in the same document
/// preview controller the JSON viewer uses.
func showMessageEditHistory(controllerInteraction: ChatControllerInteraction, chatPresentationInterfaceState: ChatPresentationInterfaceState, message: Message, context: AccountContext) {
    guard let navigationController = controllerInteraction.navigationController(), let rootController = navigationController.view.window?.rootViewController else {
        return
    }

    let strings = chatPresentationInterfaceState.strings
    let dateTimeFormat = chatPresentationInterfaceState.dateTimeFormat

    var lines: [String] = []
    let revisions = message.sgEditRevisions
    for (index, revision) in revisions.enumerated() {
        let date = stringForFullDate(timestamp: revision.date, strings: strings, dateTimeFormat: dateTimeFormat)
        lines.append("[\(index + 1)] \(date)")
        lines.append(revision.text)
        lines.append("")
    }
    let currentDate = stringForFullDate(timestamp: message.editedTime ?? message.timestamp, strings: strings, dateTimeFormat: dateTimeFormat)
    lines.append("[\(revisions.count + 1)] \(currentDate) — current")
    lines.append(message.text)

    let text = lines.joined(separator: "\n")
    guard let data = text.data(using: .utf8) else {
        return
    }

    let id = Int64.random(in: Int64.min ... Int64.max)
    let fileResource = LocalFileMediaResource(fileId: id, size: Int64(data.count), isSecretRelated: false)
    context.account.postbox.mediaBox.storeResourceData(fileResource.id, data: data, synchronous: true)

    let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: id), partialReference: nil, resource: fileResource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "text/plain; charset=utf-8", size: Int64(data.count), attributes: [.FileName(fileName: "message-history.txt")], alternativeRepresentations: [])

    presentDocumentPreviewController(rootController: rootController, theme: chatPresentationInterfaceState.theme, strings: strings, postbox: context.account.postbox, file: file, canShare: !message.isCopyProtected())
}
