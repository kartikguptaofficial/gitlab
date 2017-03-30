package gitaly

import (
	"fmt"
	"io"

	pb "gitlab.com/gitlab-org/gitaly-proto/go"
	pbhelper "gitlab.com/gitlab-org/gitaly-proto/go/helper"
	"golang.org/x/net/context"
)

type SmartHTTPClient struct {
	pb.SmartHTTPClient
}

func (client *SmartHTTPClient) InfoRefsResponseWriterTo(repo *pb.Repository, rpc string) (io.WriterTo, error) {
	rpcRequest := &pb.InfoRefsRequest{Repository: repo}
	var c pbhelper.InfoRefsClient
	var err error

	switch rpc {
	case "git-upload-pack":
		c, err = client.InfoRefsUploadPack(context.Background(), rpcRequest)
	case "git-receive-pack":
		c, err = client.InfoRefsReceivePack(context.Background(), rpcRequest)
	default:
		return nil, fmt.Errorf("InfoRefsResponseWriterTo: Unsupported RPC: %q", rpc)
	}

	if err != nil {
		return nil, fmt.Errorf("InfoRefsResponseWriterTo: RPC call failed: %v", err)
	}

	return &pbhelper.InfoRefsClientWriterTo{c}, nil
}
