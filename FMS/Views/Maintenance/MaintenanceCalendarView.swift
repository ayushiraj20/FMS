//
//  MaintenanceCalendarView.swift
//  FMS
//
//  Created by Ayush Ahuja on 22/05/26.
//

import SwiftUI

struct MaintenanceCalendarView: View {

    let orders: [WorkOrder]

    var body: some View {

        List {

            ForEach(
                groupedTasks.keys.sorted(),
                id: \.self
            ) { date in

                Section(
                    header:
                        Text(
                            date.formatted(
                                date: .complete,
                                time: .omitted
                            )
                        )
                ) {

                    ForEach(
                        groupedTasks[date] ?? []
                    ) { order in

                        HStack {

                            VStack(
                                alignment: .leading
                            ) {

                                Text(order.title)

                                Text(
                                    order.priority.rawValue
                                )
                                .font(.caption)
                            }

                            Spacer()

                            if order.priority == .critical {

                                Image(
                                    systemName:
                                    "exclamationmark.triangle.fill"
                                )
                                .foregroundStyle(.red)
                            }
                        }
                    }
                }
            }
        }
    }

    var groupedTasks: [Date:[WorkOrder]] {

        Dictionary(
            grouping: orders
        ) {

            Calendar.current
                .startOfDay(
                    for: $0.scheduledDate
                )
        }
    }
}

