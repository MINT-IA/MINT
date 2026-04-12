# MINT Flutter - Complete Navigation Actions Map

**Exhaustive extraction of every navigation action in the MINT app.**

## Summary

| Metric | Count |
|---|---|
| Screens with navigation | 62 |
| Widgets with navigation | 43 |
| Total navigation actions | 203 |
| Static routes | 40 |
| Dynamic routes (variables) | 35 |
| Dead static routes | 15 |

---

## SCREENS


### (root screens)

**achievements_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 131 | navigation | safePop() | `← back` |


### advisor

**financial_report_screen_v2.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 68 | navigation | go() | `/coach/chat` |
| 76 | navigation | go() | `/coach/chat` |
| 94 | navigation | go() | `/coach/chat` |
| 355 | navigation | push() | `/budget` |
| 448 | navigation | push() | `/budget` |
| 571 | navigation | push() | `/fiscal` |
| 744 | \u2022  | push() | _routeForCategory(action.category *(var)* |

**score_reveal_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 333 | navigation | safePop() | `← back` |
| 334 | navigation | go() | `/coach/chat` |
| 704 | navigation | go() | `/coach/chat` |
| 728 | navigation | push() | '/rapport' *(var)* |


### arbitrage

**arbitrage_bilan_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 53 | navigation | push() | `/coach/chat` |
| 282 | Arbitrage : ${item.title} | push() | item.route *(var)* |
| 379 | Débloquer : ${locked.title} | push() | locked.enrichmentRoute *(var)* |


### (root screens)

**ask_mint_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 81 | navigation | push() | `/profile/byok` |
| 134 | navigation | push() | `/profile/byok` |
| 939 | navigation | push() | `/pilier-3a` |
| 941 | navigation | push() | `/rente-vs-capital` |
| 943 | navigation | push() | `/simulator/leasing` |
| 945 | navigation | push() | `/simulator/credit` |
| 947 | navigation | push() | `/budget` |
| 950 | navigation | push() | `/education/hub` |


### auth

**forgot_password_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 78 | navigation | go() | `/auth/login` |

**login_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 53 | navigation | go() | `/coach/chat` |
| 55 | navigation | go() | `/coach/chat?prompt=onboarding` |
| 479 | navigation | go() | `/coach/chat` |
| 490 | navigation | go() | `/auth/forgot-password` |
| 505 | navigation | go() | `/auth/verify-email` |
| 528 | navigation | go() | `/auth/register` |
| 543 | navigation | go() | `/` |

**register_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 102 | navigation | go() | `/auth/verify-email?redirect=${Uri.encodeComponent(redirect)}` |
| 104 | navigation | go() | `/auth/verify-email` |
| 109 | navigation | go() | Uri.decodeComponent(redirect *(var)* |
| 112 | navigation | go() | `/coach/chat` |
| 425 | navigation | push() | `/about` |
| 439 | navigation | push() | `/about` |
| 599 | navigation | go() | `/coach/chat` |
| 616 | navigation | go() | `/auth/login` |
| 631 | navigation | go() | `/` |

**verify_email_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 84 | navigation | go() | destination *(var)* |
| 86 | navigation | go() | `/auth/login?redirect=${Uri.encodeComponent(redirect)}` |
| 88 | navigation | go() | `/auth/login` |


### budget

**budget_container_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 61 | navigation | push() | `/coach/chat?prompt=budget` |

**budget_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 241 | navigation | push() | `/coach/chat` |
| 702 | navigation | push() | `/profile/bilan` |
| 944 | navigation | push() | route *(var)* |


### (root screens)

**byok_settings_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 446 | navigation | push() | `/ask-mint` |

**cantonal_benchmark_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 79 | navigation | go() | `/coach/chat` |


### coach

**annual_refresh_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 301 | navigation | safePop() | `← back` |
| 784 | navigation | go() | `/coach/chat` |

**coach_chat_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 1377 | navigation | safePop() | `← back` |
| 1384 | navigation | push() | `/profile/byok` |

**cockpit_detail_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 520 | navigation | safePop() | `← back` |
| 559 | navigation | push() | `/scan` |

**conversation_history_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 69 | navigation | push() | `/coach/chat?conversationId=$conversationId` |
| 73 | navigation | push() | `/coach/chat` |
| 97 | navigation | safePop() | `← back` |

**retirement_dashboard_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 507 | navigation | push() | `/coach/cockpit` |
| 669 | navigation | push() | `/profile/bilan` |
| 801 | navigation | push() | `/data-block/${p.category}` |
| 916 | navigation | push() | `/coach/chat` |
| 949 | navigation | push() | `/education/hub` |
| 1037 | navigation | push() | route *(var)* |
| 1088 | navigation | push() | `/profile` |
| 1159 | navigation | push() | item.deeplink *(var)* |
| 1217 | navigation | push() | card.deeplink! *(var)* |
| 1325 | navigation | push() | `/data-block/${prompt.category}` |


### (root screens)

**concubinage_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 121 | navigation | safePop() | `← back` |


### confidence

**confidence_dashboard_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 149 | navigation | safePop() | `← back` |


### (root screens)

**coverage_check_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 181 | navigation | safePop() | `← back` |


### debt_prevention

**debt_ratio_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 944 | navigation | push() | `/debt/repayment` |

**repayment_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 143 | navigation | safePop() | `← back` |


### (root screens)

**debt_risk_check_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 286 | navigation | safePop() | `← back` |


### disability

**disability_gap_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 458 | navigation | push() | route *(var)* |


### (root screens)

**document_detail_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 64 | navigation | safePop() | `← back` |
| 288 | navigation | safePop() | `← back` |
| 528 | navigation | safePop() | `← back` |


### document_scan

**avs_guide_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 102 | navigation | safePop() | `← back` |
| 466 | navigation | push() | '/scan' *(var)* |
| 486 | navigation | push() | '/scan/review' *(var)* |

**document_impact_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 578 | navigation | go() | `/coach/chat` |
| 626 | navigation | go() | `/coach/chat` |

**document_scan_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 150 | navigation | safePop() | `← back` |
| 561 | navigation | push() | '/scan/review' *(var)* |
| 713 | navigation | push() | '/scan/review' *(var)* |
| 940 | navigation | go() | `/auth/register` |
| 1231 | navigation | push() | '/scan/review' *(var)* |
| 1451 | navigation | push() | '/scan/review' *(var)* |

**extraction_review_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 127 | navigation | safePop() | `← back` |
| 713 | navigation | push() | '/scan/impact' *(var)* |


### (root screens)

**documents_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 68 | navigation | safePop() | `← back` |
| 542 | navigation | push() | `/documents/${doc.id}` |
| 668 | navigation | safePop() | `← back` |
| 775 | navigation | push() | `/documents/${result.id}` |
| 936 | navigation | push() | `/bank-import` |


### education

**comprendre_hub_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 65 | navigation | push() | `/education/theme/${theme.id}` |

**theme_detail_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 86 | navigation | safePop() | `← back` |
| 207 | navigation | push() | theme.route *(var)* |
| 673 | navigation | push() | theme.route *(var)* |


### (root screens)

**expat_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 146 | navigation | safePop() | `← back` |

**first_job_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 286 | navigation | safePop() | `← back` |

**fiscal_comparator_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 334 | navigation | safePop() | `← back` |

**frontalier_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 139 | navigation | safePop() | `← back` |

**gender_gap_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 103 | navigation | safePop() | `← back` |


### household

**accept_invitation_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 187 | navigation | go() | `/couple` |

**household_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 126 | navigation | push() | `/auth/login` |
| 509 | navigation | push() | `/household/accept` |


### (root screens)

**independant_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 225 | navigation | safePop() | `← back` |


### independants

**dividende_vs_salaire_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 114 | navigation | safePop() | `← back` |

**lpp_volontaire_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 108 | navigation | safePop() | `← back` |

**pillar_3a_indep_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 107 | navigation | safePop() | `← back` |


### (root screens)

**lamal_franchise_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 128 | navigation | safePop() | `← back` |

**landing_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 98 | MINT | go() | `/auth/login` |
| 147 | navigation | go() | `/coach/chat` |
| 169 | navigation | go() | `/auth/login` |


### lpp_deep

**epl_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 250 | navigation | safePop() | `← back` |

**libre_passage_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 96 | navigation | safePop() | `← back` |


### (root screens)

**mariage_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 132 | navigation | safePop() | `← back` |


### mortgage

**affordability_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 753 | navigation | push() | route *(var)* |


### (root screens)

**naissance_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 141 | navigation | safePop() | `← back` |


### onboarding

**data_block_enrichment_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 92 | navigation | safePop() | `← back` |
| 119 | navigation | push() | `/coach/chat?prompt=${Uri.encodeComponent(prompt)}` |
| 160 | navigation | push() | route *(var)* |
| 162 | navigation | safePop() | `← back` |


### open_banking

**consent_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 142 | navigation | safePop() | `← back` |

**open_banking_hub_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 116 | navigation | safePop() | `← back` |
| 572 | navigation | push() | route *(var)* |

**transaction_list_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 146 | navigation | safePop() | `← back` |


### pillar_3a_deep

**provider_comparator_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 96 | navigation | safePop() | `← back` |

**retroactive_3a_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 205 | navigation | safePop() | `← back` |
| 215 | navigation | push() | `/coach/chat` |
| 234 | navigation | safePop() | `← back` |

**staggered_withdrawal_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 183 | navigation | push() | `/coach/chat` |


### profile

**financial_summary_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 68 | navigation | safePop() | `← back` |
| 90 | navigation | push() | `/coach/chat` |
| 172 | navigation | push() | `/scan` |
| 311 | navigation | push() | `/scan` |
| 328 | navigation | push() | `/coach/chat` |


### (root screens)

**simulator_3a_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 694 | navigation | push() | route *(var)* |

**timeline_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 389 | navigation | push() | action.route *(var)* |
| 486 | navigation | push() | event.route *(var)* |

**unemployment_screen.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 94 | navigation | safePop() | `← back` |


---

## WIDGETS


### (root widgets)

**action_insight_widget.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 64 | navigation | push() | route! *(var)* |


### auth

**auth_gate.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 234 | navigation | pop() | `← back` |
| 261 | navigation | pop() | `← back` |


### coach

**coach_interrupt_banner.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 176 | navigation | push() | widget.interrupt.ctaRoute! *(var)* |

**coach_message_bubble.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 350 | navigation | push() | `/pilier-3a` |
| 352 | navigation | push() | `/rente-vs-capital` |
| 354 | navigation | push() | `/fiscal` |
| 356 | navigation | push() | `/retraite` |
| 358 | navigation | push() | `/budget` |
| 360 | navigation | push() | `/education/hub` |

**coach_paywall_sheet.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 158 | navigation | pop() | `← back` |
| 454 | navigation | pop() | `← back` |
| 500 | navigation | pop() | `← back` |

**confidence_blocks_bar.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 82 | navigation | push() | `/data-block/${db.dataBlockType}` |

**data_quality_card.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 322 | navigation | push() | `/scan` |

**early_retirement_comparison.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 202 | Simuler ta retraite anticipée | push() | `/coach/cockpit` |

**explore_hub.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 93 | interactive element | push() | route *(var)* |

**hero_retirement_card.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 478 | navigation | push() | `/scan` |

**indicatif_banner.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 99 | navigation | push() | `/data-block/$route` |

**low_confidence_card.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 103 | navigation | push() | route *(var)* |
| 145 | navigation | push() | bestRoute *(var)* |

**micro_action_card.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 47 | navigation | push() | action.deeplink *(var)* |

**milestone_celebration_sheet.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 188 | navigation | pop() | `← back` |

**premier_eclairage_card_coach.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 135 | navigation | push() | ctaRoute *(var)* |

**response_card_widget.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 576 | navigation | push() | card.cta.route *(var)* |

**route_suggestion_card.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 89 | navigation | push() | route *(var)* |

**smart_shortcuts.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 48 | Voir ton bilan détaillé | push() | `/coach/cockpit` |
| 93 | navigation | push() | s.route *(var)* |

**temporal_strip.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 66 | interactive element | push() | item.deeplink *(var)* |

**trajectory_card.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 54 | navigation | push() | `/coach/cockpit` |

**what_if_stories_widget.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 111 | navigation | push() | story.route! *(var)* |

**widget_renderer.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 170 | navigation | push() | route *(var)* |
| 203 | navigation | push() | `/retraite` |
| 235 | navigation | push() | `/budget` |
| 566 | navigation | push() | `/documents` |


### common

**debt_tools_nav.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 88 | navigation | push() | tool.route *(var)* |

**safe_mode_gate.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 152 | navigation | push() | ctaRoute! *(var)* |


### dashboard

**arbitrage_teaser_card.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 55 | Voir tout | push() | `/arbitrage/bilan` |
| 223 | navigation | push() | teaser.route *(var)* |

**couple_action_plan.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 117 | navigation | push() | action.route! *(var)* |

**document_scan_cta.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 62 | Scan | push() | `/scan` |

**retirement_checklist_card.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 111 | navigation | push() | item.route! *(var)* |


### educational

**generic_info_insert_widget.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 161 | navigation | push() | actionRoute! *(var)* |


### (root widgets)

**fullscreen_chart_wrapper.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 147 | navigation | pop() | `← back` |


### home

**action_opportunity_card.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 43 | navigation | push() | card.route *(var)* |

**anticipation_signal_card.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 122 | navigation | push() | signal.simulatorLink *(var)* |

**hero_stat_card.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 45 | ${card.label}: ${card.value} | push() | card.route *(var)* |

**progress_milestone_card.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 44 | ${card.title}, ${card.percent.toInt()}\u00a0% | push() | card.route *(var)* |


### (root widgets)

**life_event_suggestions.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 254 | navigation | push() | suggestion.route *(var)* |

**mentor_fab.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 163 | navigation | push() | action.route *(var)* |

**profile_drawer.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 133 | navigation | go() | `/` |
| 277 | navigation | push() | route *(var)* |


### pulse

**action_success_sheet.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 194 | navigation | pop() | `← back` |
| 195 | navigation | push() | data.nextRoute! *(var)* |
| 234 | navigation | pop() | `← back` |

**cap_sequence_card.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 77 | navigation | go() | step.intentTag! *(var)* |

**comprendre_section.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 87 | navigation | push() | item.route *(var)* |

**pulse_action_card.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 28 | navigation | push() | action.route *(var)* |


### (root widgets)

**recommendation_card.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 149 | navigation | push() | action.deepLink! *(var)* |

**settings_sheet.dart** 

| Ln | Widget | Method | Destination |
|---:|---|---|---|
| 159 | navigation | push() | item.route *(var)* |


---

## DEAD DESTINATIONS

Found 15 static routes not in app.dart:

- `/auth/login?redirect=${Uri.encodeComponent(redirect)}`
- `/auth/verify-email?redirect=${Uri.encodeComponent(redirect)}`
- `/coach/chat?conversationId=$conversationId`
- `/coach/chat?prompt=${Uri.encodeComponent(prompt)}`
- `/coach/chat?prompt=budget`
- `/coach/chat?prompt=onboarding`
- `/data-block/$route`
- `/data-block/${db.dataBlockType}`
- `/data-block/${p.category}`
- `/data-block/${prompt.category}`
- `/documents/${doc.id}`
- `/documents/${result.id}`
- `/education/theme/${theme.id}`
- `/profile/bilan`
- `/profile/byok`

### Dynamic Routes (resolved at runtime)

(35 total, including variables like `item.route`, `card.deeplink`, etc.)
