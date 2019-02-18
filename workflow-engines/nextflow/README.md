

# Start nextflow container

```bash
docker build -t nextflow .
docker run -v $(pwd)/pipelines/:/pipelines/:ro -it nextflow /bin/bash
```

run the following command in the container

```
mkdir tools
cd tools
curl -s https://get.nextflow.io | bash
cd ..
./tools/nextflow run pipelines/tutorial.nf
```
