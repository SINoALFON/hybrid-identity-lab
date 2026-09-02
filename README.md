# Hybrid Identity Environment

## Overview
This lab simulates a post-production media company, using Active Directory administration, identity lifecycle management, and synchronization to Microsoft Entra ID. The goal is a system where assets and tools can be coordinated seamlessly among a team of staff, freelancers, and vendors, within tightly scoped access boundaries.

## Scenario
SINoALFON Media (S-Media for short) is a post-production facility that handles a breadth of assets for streaming and production companies. In order to process the amount of incoming work, S-Media employs in-house staff as well as contracting out overflow to individual freelancers and vendors, who may work on anywhere from a single project to several. As most of the assets S-Media handles are sensitive, unreleased client content, they need a system through which they can coordinate access while simultaneously reinforcing content security. This system also needs to be highly fluid, able to handle onboarding and deprovisioning of workers quickly while keeping project material access scoped to what is needed.

## Architecture
- Hyper-V on Windows 11, internal virtual switch
- Network: 10.10.10.0/24
- DC01 — Windows Server 2025, 10.10.10.10, domain controller and DNS
- Domain: corp.sinoalfon.com (NetBIOS: SINOALFON)

## Build log

## Problems and solutions

## Skills demonstrated
