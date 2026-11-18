import PearlKit
import SwiftUI

/// The screen that gets Stremio to hand streams to Pearl, and the screen that
/// explains the two ways to do it.
struct StremioSetupView: View {
    private let userScript = StremioUserScript.source

    var body: some View {
        List {
            Section("How the handoff works") {
                Text(
                    """
                    Stremio builds a link for whichever external player you picked in \
                    its settings, and iOS opens whichever app registered that link. \
                    Pearl claims the Outplayer, VLC and Stremio handoff links, plus \
                    its own pearl:// link for the userscript route.
                    """
                )
                .font(.callout)
            }

            Section("Route 1: Stremio's own setting") {
                Text(
                    """
                    1. In Stremio, Settings, Player, set Play in external player to \
                    VLC or Outplayer.
                    2. Delete the real VLC or Outplayer app so Pearl is the app that \
                    answers that link.
                    3. Open a stream. It opens here.
                    """
                )
                .font(.callout)
            }

            Section("Route 2: the userscript, progress sync included") {
                Text(
                    """
                    With the Userscripts extension in Safari, this script rewrites \
                    Stremio Web stream clicks to Pearl and passes the detail page \
                    along, which is what lets Pearl report your position back to \
                    Stremio when you close the player.
                    """
                )
                .font(.callout)
                Button {
                    UIPasteboard.general.string = userScript
                } label: {
                    Label("Copy the userscript", systemImage: "doc.on.doc")
                }
            }

            Section("What Pearl sends back") {
                Text(
                    """
                    When the handoff carried a detail link, leaving the player opens \
                    stremio:///detail/... with your position, so Stremio remembers \
                    where you stopped. Dropdown handoffs carry no detail link, so \
                    there is nothing to report in that route.
                    """
                )
                .font(.callout)
            }
        }
        .navigationTitle("Stremio")
    }
}
