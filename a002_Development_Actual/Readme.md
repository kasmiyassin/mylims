# To do

Development of this database need to reoptimize the structure and design to reply to need to both teams, fisheries and Genetics, and covering all informations.

- [X] Restructure the schemas according to the needs.
- [X] Tables restructuring
- [ ] what news tables anf schemas
## ToDo informations

- [X] GIS change geometry to geogrphy
- [X] Remove partitioning from all tables, because it complicates to add new data and there is need to mi



# Ideas

DATABASE: demo
├── reference 
│   ├── *category
│   ├── *ecosystem
│   ├── *genes
│   ├── *reference_databases
│   ├── *region
│   ├── *sampling_type
│   ├── *status
│   ├── *taxon
│   └── *units
│
├── core
│   ├── *persons
│   ├── *organizations (Organizations, Suppliers)
│   ├── *equipments
│   ├── *vessel
│   └── *locations (rooms, building, officies)
│
├── lims (Logistics & People)
│   ├── *projects (Project metadata, Funding, Roles)
│   ├── *project_personnel
│   ├── *project_permit
│   ├── *reagents
│   ├── *storage 
│   ├── *experiments
│   ├── *experiments_projects
│   ├── *experiments_samples
│   └── *sop
│
├── field
│   ├── *cruises (Cruises and expeditions)
│   ├── *fishing
│   ├── *sampling_event
│   ├── *sampling_abiotic
│   └── *catch
│
├── bio_assets
│   ├── *samples_reservation
│   ├── *samples_root
│   ├── *organisms (Typed fish data: Length, weight, sex)
│   ├── tissue
│   ├── dna
│   ├── rna
│   ├── sediments
│   └── water
│
├── biologyfish
│   ├── otoliths
│   ├── dissection
│   ├── stomach_content
│   └── tag_mark
│
├── moleculargenetics
│   ├── pcr
│   ├── qpcr
│   ├── gelelectrophoresis
│   ├── library
│   ├── nanodrop
│   ├── qubit
│   ├── tapestation
│   ├── sequencing_flowcells
│   └── sequencing (Raw runs)
│
├── bioinformatics (Computational Data)
│   ├── pipelines (Software versions, parameters)
│   ├── seq_dataset (FASTQ or FASTA)
│   └── assignments (Taxonomic read counts and OTU tables)
│
└── Communications
│   ├── projects_chat 
│   ├── internal_plans
│   └── reports
│
├── eln
│   ├── batch
│   ├── bookable_ressources
│   ├── protocols (write and run protocols)
│   ├── protocols_run (write and run protocols)
│   └── 
│
└── Audit
│   ├── audit_log 
