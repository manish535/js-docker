#!/bin/bash

# Copyright (c) 2019. TIBCO Software Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.

# Wraps the jasperserver-pro entrypoint.sh to load license and
# other config files from a given S3 bucket

. ./common-environment-aws.sh

initialize_from_S3
BASE_ENTRYPOINT=${BASE_ENTRYPOINT:-/entrypoint-cmdline.sh}

case "$1" in
  init)
    ( ${BASE_ENTRYPOINT} "$@" )
    ;;

  import)
    # args are:
    #   mode: s3 or mnt
    #   in-order volumes or A_BUCKET_NAME/folder
    echo "$@"
    shift 1
    case "$1" in
      s3)
        # in-order A_BUCKET_NAME_1/folder1 A_BUCKET_NAME_2/folder2/import-properties-file
        shift 1
        # copy contents to /tmp/${bucketAndFolder}
        for bucketPath in $@; do
		  importFileName="import.properties"
		  bucketAndFolder="$bucketPath"

		  # custom volume/properties file; not a folder
		  if aws s3 ls s3://${bucketPath} ; then
		    importFileName="${bucketPath##*/}"
		    bucketAndFolder="${bucketPath%/*}"
		  fi
		  
          if aws s3 ls s3://${bucketAndFolder}/${importFileName} ; then
            echo "Loading import from s3: ${bucketAndFolder}"
            mkdir -p /tmp/${bucketAndFolder}
            #aws s3 ls s3://${bucketAndFolder} --recursive
            aws s3 cp s3://${bucketAndFolder} /tmp/${bucketAndFolder} --recursive
            #ls /tmp/${bucketAndFolder}

            ( ${BASE_ENTRYPOINT} import "/tmp/${bucketAndFolder}/${importFileName}" )

            # copy results back into s3 ${bucketAndFolder}
            aws s3 cp /tmp/${bucketAndFolder} s3://${bucketAndFolder}/ --recursive
            aws s3 rm s3://${bucketAndFolder}/${importFileName}
            rm -rf /tmp/${bucketAndFolder}
          fi
        done
        for bucketAndFolder in $@; do
        done
        ;;
      mnt)
        shift 1
        ( ${BASE_ENTRYPOINT} import "$@" )
        ;;
    esac
    ;;

  export)

    # export: args are in-order EXPORT_S3_BUCKET_NAME/folder
    # copy contents to /tmp/EXPORT_S3_BUCKET_NAME/folder
    ( ${BASE_ENTRYPOINT} "$@" )
    # copy results back into EXPORT_S3_BUCKET_NAME/folder

    # args are:
    #   mode: s3 or mnt
    #   in-order volumes or A_BUCKET_NAME/folder
    echo "$@"
    shift 1
    case "$1" in
      s3)
        # in-order A_BUCKET_NAME_1/folder1 A_BUCKET_NAME_2/folder2
        shift 1
        command=""
        # copy contents to /tmp/${bucketAndFolder}
        for bucketPath in $@; do
		  exportFileName="export.properties"
		  bucketAndFolder="$bucketPath"

		  # custom volume/properties file; not a folder
		  if aws s3 ls s3://${bucketPath} ; then
		    exportFileName="${bucketPath##*/}"
		    bucketAndFolder="${bucketPath%/*}"
		  fi

          echo "Exporting to s3: ${bucketAndFolder}"
          mkdir -p /tmp/${bucketAndFolder}
          aws s3 cp s3://${bucketAndFolder}/${exportFileName} /tmp/${bucketAndFolder}
          ( ${BASE_ENTRYPOINT} export "/tmp/${bucketAndFolder}/${exportFileName}" )
          # copy export results into ${bucketAndFolder}
          aws s3 cp /tmp/${bucketAndFolder} s3://${bucketAndFolder} --recursive
          aws s3 rm s3://${bucketAndFolder}/${exportFileName}
          rm -rf /tmp/${bucketAndFolder}
        done
        ;;
      mnt)
        shift 1
        ( ${BASE_ENTRYPOINT} export "$@" )
        ;;
    esac
    ;;
  *)
    exec "$@"
esac

save_jrsks_to_S3
