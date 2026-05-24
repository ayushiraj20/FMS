//
//  BroadcastRowView.swift
//  FMS
//
//  Created by Ayush Ahuja on 22/05/26.
//

import SwiftUI

struct BroadcastRowView: View {

    let message: BroadcastMessage

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 10
        ) {

            HStack {

                Text(
                    message.title
                )
                .font(
                    .headline
                )

                Spacer()

                Text(
                    message.sentAt.formatted(
                        date:
                        .abbreviated,
                        time:
                        .shortened
                    )
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .gray
                )
            }

            Text(
                message.message
            )
            .font(
                .body
            )

            Label(
                message.senderName,
                systemImage:
                "person.fill"
            )
            .font(
                .caption
            )
            .foregroundStyle(
                .blue
            )

        }
        .padding(
            .vertical,
            5
        )
    }
}
